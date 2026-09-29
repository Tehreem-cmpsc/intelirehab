import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import '../home/wearable_connection_controller.dart';
import '../onboarding/onboarding_repository.dart';
import 'profile_models.dart';

/// The Profile screen's data + the writes it can make. Reuses
/// OnboardingRepository's clinic/physio lookups (patients have no direct
/// read access to `clinics`/`physiotherapists` — only those SECURITY
/// DEFINER functions) and its error-message wrapping, rather than
/// duplicating either.
class ProfileRepository {
  final OnboardingRepository _onboarding;
  SupabaseClient get _db => supabase;

  ProfileRepository({OnboardingRepository? onboarding}) : _onboarding = onboarding ?? OnboardingRepository();

  Future<ProfileData> load() async {
    final row = await _db.from('patients').select().single();

    String? clinicName;
    String? physioName;
    final clinicId = row['clinic_id'] as String?;
    final physioId = row['physio_id'] as String?;
    if (clinicId != null) {
      final clinics = await _onboarding.listClinics();
      clinicName = clinics.where((c) => c.id == clinicId).firstOrNull?.name;
      if (physioId != null) {
        final physios = await _onboarding.listPhysiotherapists(clinicId);
        physioName = physios.where((p) => p.id == physioId).firstOrNull?.fullName;
      }
    }

    final deviceRow = await _db
        .from('wearable_devices')
        .select('id, serial_no, firmware_version')
        .eq('patient_id', row['id'] as String)
        .eq('status', 'paired')
        .maybeSingle();

    return ProfileData(
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      email: row['email'] as String? ?? '',
      dateOfBirth: DateTime.tryParse(row['date_of_birth'] as String? ?? ''),
      gender: (row['gender'] as String?)?.let((g) => g.isEmpty ? null : g),
      heightCm: (row['height_cm'] as num?)?.toDouble(),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      clinicName: clinicName,
      physioName: physioName,
      device: deviceRow == null
          ? null
          : PairedDevice(
              id: deviceRow['id'] as String,
              serial: deviceRow['serial_no'] as String? ?? '',
              firmware: deviceRow['firmware_version'] as String?,
              batteryPercent: simulatedWearableBattery(deviceRow['serial_no'] as String? ?? deviceRow['id'] as String),
            ),
    );
  }

  /// Personal Info's Save button. Scoped to exactly these columns by
  /// update_patient_profile (supabase_patient_profile_self_edit.sql) —
  /// email/clinic/physio/approval fields aren't touchable from here.
  Future<void> saveProfile({
    required String name,
    required String phone,
    required DateTime? dateOfBirth,
    required String? gender,
    required double? heightCm,
    required double? weightKg,
  }) {
    return _call(() => _db.rpc('update_patient_profile', params: {
          'p_name': name.trim(),
          'p_phone': phone.trim(),
          'p_date_of_birth': dateOfBirth == null
              ? null
              : '${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
          'p_gender': gender,
          'p_height_cm': heightCm,
          'p_weight_kg': weightKg,
        }));
  }

  /// [Forget wearable]. wearable_devices has a full "own device" RLS
  /// policy (see supabase_full_schema_snapshot.sql), so a plain delete is
  /// enough — the sync trigger clears patients.wearable_connected, and
  /// sessions.device_id is ON DELETE SET NULL.
  Future<void> forgetDevice(String deviceId) {
    return _call(() => _db.from('wearable_devices').delete().eq('id', deviceId));
  }

  /// BR-2's "re-enter current password": Supabase has no verify-only call,
  /// so the current password is checked by signing in with it again before
  /// applying the new one.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final email = _db.auth.currentUser?.email;
    if (email == null) throw const OnboardingException('You need to be signed in.');
    try {
      await _db.auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthException {
      throw const OnboardingException('Current password is incorrect.');
    }
    await _call(() => _db.auth.updateUser(UserAttributes(password: newPassword)));
  }

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw OnboardingException(e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.');
    } on AuthException catch (e) {
      throw OnboardingException(e.message.isNotEmpty ? e.message : 'Something went wrong. Please try again.');
    } on OnboardingException {
      rethrow;
    } catch (_) {
      throw const OnboardingException("Couldn't reach Inteli Rehab. Check your connection and try again.");
    }
  }
}

extension _NullIfLet<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
