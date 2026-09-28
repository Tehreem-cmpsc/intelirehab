import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import 'onboarding_data.dart';

/// A failure worth showing the patient as-is.
class OnboardingException implements Exception {
  final String message;
  const OnboardingException(this.message);

  @override
  String toString() => message;
}

enum SignUpResult { registered, needsEmailConfirmation }

/// Every Supabase call the onboarding flow makes, one method per step.
///
///   Contact       -> auth.signUp + register_patient_self()  (patients, patient_injuries)
///   Clinic/physio -> list_onboarding_clinics(), list_clinic_physiotherapists(),
///                    choose_clinic_and_physio()             (patients.clinic_id / physio_id)
///   Wearable      -> wearable_devices insert/update
///   Calibration   -> sessions + movement_analysis (posture_status = 'baseline_calibration')
///
/// The RPCs are SECURITY DEFINER functions in Intelli_Rehab_Web_Portal/
/// supabase_patient_*.sql; the table writes go through the existing
/// "own patient" RLS policies.
class OnboardingRepository {
  /// Marks the calibration session's movement_analysis row, so the
  /// baseline can be told apart from exercise sessions.
  static const baselineMarker = 'baseline_calibration';
  static const _metadataKey = 'onboarding';

  SupabaseClient get _db => supabase;

  // ------------------------------------------------------------
  // Contact step
  // ------------------------------------------------------------

  /// Creates the login and, when a session comes back straight away,
  /// the patient record. With email confirmation on there's no session
  /// yet — the answers ride along in user metadata and
  /// [completeRegistrationFromMetadata] finishes on first sign-in.
  Future<SignUpResult> createAccount(OnboardingData data) async {
    final params = data.registrationParams();

    // Retry after the login was created but registration failed (e.g. a
    // dropped connection): signing up again would only say "already
    // registered", so just finish registering the signed-in account.
    final current = _db.auth.currentUser;
    if (current != null && current.email?.toLowerCase() == data.email.trim().toLowerCase()) {
      data.patientId = await _register(params);
      return SignUpResult.registered;
    }

    final AuthResponse res;
    try {
      res = await _db.auth.signUp(
        email: data.email.trim(),
        password: data.password,
        data: {_metadataKey: params},
      );
    } on AuthException catch (e) {
      throw OnboardingException(_authMessage(e));
    }

    final user = res.user;
    if (user == null) throw const OnboardingException('Could not create your account. Please try again.');
    // With confirmation on, Supabase hides "already registered" by
    // returning a user with no identities instead of an error.
    if (user.identities != null && user.identities!.isEmpty) {
      throw const OnboardingException('An account with this email already exists. Sign in instead.');
    }
    if (res.session == null) return SignUpResult.needsEmailConfirmation;

    data.patientId = await _register(params);
    return SignUpResult.registered;
  }

  /// For a signed-in user with no patients row yet: registers from the
  /// answers saved at sign-up. Returns null if there are none.
  Future<String?> completeRegistrationFromMetadata() async {
    final saved = _db.auth.currentUser?.userMetadata?[_metadataKey];
    if (saved is! Map) return null;
    return _register(Map<String, dynamic>.from(saved));
  }

  Future<String> _register(Map<String, dynamic> params) async {
    final row = await _call(() => _db.rpc('register_patient_self', params: params));
    // Registered — the copy in auth metadata is no longer needed.
    try {
      await _db.auth.updateUser(UserAttributes(data: {_metadataKey: null}));
    } catch (_) {
      // Harmless if it stays; register_patient_self is idempotent.
    }
    return (row as Map)['id'] as String;
  }

  // ------------------------------------------------------------
  // Clinic / physiotherapist step
  // ------------------------------------------------------------

  Future<List<Clinic>> listClinics() async {
    final rows = await _call(() => _db.rpc('list_onboarding_clinics'));
    return [for (final r in rows as List) Clinic.fromMap(Map<String, dynamic>.from(r as Map))];
  }

  Future<List<Physiotherapist>> listPhysiotherapists(String clinicId) async {
    final rows = await _call(() => _db.rpc('list_clinic_physiotherapists', params: {'p_clinic_id': clinicId}));
    return [for (final r in rows as List) Physiotherapist.fromMap(clinicId, Map<String, dynamic>.from(r as Map))];
  }

  Future<void> chooseClinicAndPhysio(Clinic clinic, Physiotherapist physio) async {
    await _call(() => _db.rpc('choose_clinic_and_physio', params: {
          'p_clinic_id': clinic.id,
          'p_physio_id': physio.id,
        }));
  }

  // ------------------------------------------------------------
  // Wearable step
  // ------------------------------------------------------------

  /// Records [device] as the patient's paired band and marks any band
  /// paired before it as replaced. Returns the wearable_devices id.
  Future<String> saveWearable(String patientId, WearableDevice device) async {
    return _call(() async {
      await _db
          .from('wearable_devices')
          .update({'status': 'replaced'})
          .eq('patient_id', patientId)
          .eq('status', 'paired')
          .neq('serial_no', device.id);

      final existing = await _db
          .from('wearable_devices')
          .select('id')
          .eq('patient_id', patientId)
          .eq('serial_no', device.id)
          .maybeSingle();

      final fields = {
        'status': 'paired',
        'firmware_version': device.firmware,
        'mac_address': device.macAddress,
      };
      if (existing != null) {
        await _db.from('wearable_devices').update(fields).eq('id', existing['id'] as String);
        return existing['id'] as String;
      }
      final inserted = await _db
          .from('wearable_devices')
          .insert({'patient_id': patientId, 'serial_no': device.id, ...fields})
          .select('id')
          .single();
      return inserted['id'] as String;
    });
  }

  // ------------------------------------------------------------
  // Calibration step
  // ------------------------------------------------------------

  /// Stores the baseline as the patient's first session (rom = range,
  /// no exercise) plus its movement_analysis row.
  Future<void> saveBaseline({
    required String patientId,
    required String? deviceRecordId,
    required BaselineReading baseline,
    required int reps,
  }) async {
    await _call(() async {
      final session = await _db
          .from('sessions')
          .insert({
            'patient_id': patientId,
            'device_id': deviceRecordId,
            'rom': baseline.range,
            'reps': reps,
          })
          .select('id')
          .single();
      await _db.from('movement_analysis').insert({
        'session_id': session['id'],
        'joint_angle': baseline.flexion,
        'rom': baseline.range,
        'repetition_count': reps,
        'posture_status': baselineMarker,
      });
    });
  }

  // ------------------------------------------------------------
  // Resuming
  // ------------------------------------------------------------

  /// Rebuilds onboarding answers from a patients row, so a returning
  /// patient resumes where they left off (or sees the waiting screen
  /// with their real clinic, physio, band and baseline).
  Future<OnboardingData> hydrate(Map<String, dynamic> patient) async {
    final patientId = patient['id'] as String;
    final data = OnboardingData()
      ..patientId = patientId
      ..fullName = (patient['name'] as String?) ?? ''
      ..phone = (patient['phone'] as String?) ?? ''
      ..email = (patient['email'] as String?) ?? ''
      ..dateOfBirth = DateTime.tryParse(patient['date_of_birth'] as String? ?? '')
      ..gender = _nonEmpty(patient['gender'])
      ..activityLevel = _nonEmpty(patient['activity_level'])
      ..dominantArm = _nonEmpty(patient['dominant_arm']);

    final injury = await _db
        .from('patient_injuries')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (injury != null) {
      data
        ..affectedSide = injury['affected_side'] as String?
        ..affectedJoint = injury['affected_joint'] as String?
        ..injuryType = injury['injury_type'] as String?
        ..injuryCause = injury['cause'] as String?
        ..injuryDate = DateTime.tryParse(injury['diagnosis_date'] as String? ?? '')
        ..firstInjury = injury['first_injury'] as bool?
        ..painLevel = (injury['pain_level'] as num?)?.toInt();
    }

    final clinicId = patient['clinic_id'] as String?;
    if (clinicId != null) {
      final clinics = await listClinics();
      data.clinic = clinics.where((c) => c.id == clinicId).firstOrNull;
      final physioId = patient['physio_id'] as String?;
      if (physioId != null) {
        final physios = await listPhysiotherapists(clinicId);
        data.physio = physios.where((p) => p.id == physioId).firstOrNull;
      }
    }

    final device = await _db
        .from('wearable_devices')
        .select('id, serial_no, firmware_version, mac_address')
        .eq('patient_id', patientId)
        .eq('status', 'paired')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (device != null) {
      final serial = (device['serial_no'] as String?) ?? '';
      data
        ..deviceRecordId = device['id'] as String
        ..wearable = WearableDevice(
          serial,
          'Inteli Band ${serial.length > 4 ? serial.substring(serial.length - 4) : serial}',
          3,
          null,
          firmware: device['firmware_version'] as String?,
          macAddress: device['mac_address'] as String?,
        );
    }

    final baseline = await _db
        .from('sessions')
        .select('id, movement_analysis!inner(joint_angle, rom, posture_status)')
        .eq('patient_id', patientId)
        .eq('movement_analysis.posture_status', baselineMarker)
        .order('performed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final analysis = (baseline?['movement_analysis'] as List?)?.firstOrNull as Map?;
    if (analysis != null) {
      final flexion = (analysis['joint_angle'] as num).round();
      final range = (analysis['rom'] as num).round();
      data
        ..baseline = BaselineReading(neutral: 0, flexion: flexion, extension: flexion - range)
        ..baselineSaved = true;
    }

    return data;
  }

  static String? _nonEmpty(Object? v) => (v is String && v.isNotEmpty) ? v : null;

  // ------------------------------------------------------------

  /// Runs a Supabase call, turning its errors into patient-readable ones.
  /// RPCs raise plain-language messages (e.g. "That physiotherapist is
  /// not available at this clinic."), so those are passed through.
  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw OnboardingException(e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.');
    } on AuthException catch (e) {
      throw OnboardingException(_authMessage(e));
    } on OnboardingException {
      rethrow;
    } catch (_) {
      throw const OnboardingException("Couldn't reach Inteli Rehab. Check your connection and try again.");
    }
  }

  static String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (m.contains('password')) return e.message;
    if (m.contains('rate limit') || e.statusCode == '429') {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    return e.message.isNotEmpty ? e.message : 'Could not create your account. Please try again.';
  }
}
