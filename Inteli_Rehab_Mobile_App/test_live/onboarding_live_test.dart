// End-to-end onboarding check against the LIVE Supabase project.
//
// Not part of `flutter test` (it lives outside test/). Run on purpose with:
//
//   flutter test test_live/onboarding_live_test.dart
//
// It signs up a throwaway patient, runs every onboarding save through the
// app's real OnboardingRepository, checks each row landed where the portal
// expects it, then deletes the account with delete_my_account() — even if
// a check fails part-way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/network/supabase_client.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/onboarding_data.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/onboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ignore_for_file: avoid_print

// Local fixtures for exercising OnboardingRepository.saveWearable's
// replace-on-repair logic — this test is checking that repository method
// against the live DB, not doing a real BLE scan, so plain WearableDevice
// values are all it needs (mock_directory.dart, the UI's old mock
// catalogue, is gone now that pairing is real BLE).
const _testDevice1 = WearableDevice('TEST-A1F3', 'Test Band A1F3', 3, 86, firmware: '1.4.2');
const _testDevice2 = WearableDevice('TEST-7C02', 'Test Band 7C02', 1, 54, firmware: '1.4.2');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test stubs out HTTP; this test needs the real network.
    HttpOverrides.global = null;
    await initSupabase(
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryAsyncStorage(),
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  });

  test('onboarding saves every step to Supabase', () async {
    final repo = OnboardingRepository();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final data = OnboardingData()
      ..fullName = 'E2E Test Patient'
      ..dateOfBirth = DateTime(1990, 5, 17)
      ..gender = 'female'
      ..activityLevel = 'active'
      ..dominantArm = 'right'
      ..affectedSide = 'right'
      ..affectedJoint = 'elbow'
      ..injuryType = 'fracture'
      ..injuryCause = 'fall'
      ..injuryDate = DateTime.now().subtract(const Duration(days: 20))
      ..firstInjury = true
      ..painLevel = 2
      ..phone = '0300 1234567'
      ..email = 'inteli-rehab-e2e-$stamp@mailinator.com'
      ..password = 'E2eTest$stamp'
      ..termsAccepted = true;

    print('  test account: ${data.email}');
    try {
      // --- Contact: sign-up + register_patient_self --------------------
      final result = await repo.createAccount(data);
      expect(result, SignUpResult.registered, reason: 'project has email auto-confirm on');
      expect(data.patientId, isNotNull);
      print('✓ account + patient ${data.patientId} (${data.email})');

      final patient = await supabase.from('patients').select().eq('id', data.patientId!).single();
      expect(patient['name'], 'E2E Test Patient');
      expect(patient['email'], data.email);
      expect(patient['phone'], '0300 1234567');
      expect(patient['date_of_birth'], '1990-05-17');
      expect(patient['gender'], 'female');
      expect(patient['activity_level'], 'active');
      expect(patient['dominant_arm'], 'right');
      expect(patient['injury'], 'Elbow');
      expect(patient['injury_side'], 'Right');
      expect(patient['approved'], false);
      expect(patient['clinic_id'], isNull);
      expect(patient['terms_accepted_at'], isNotNull);
      print('✓ patients row');

      final injury = await supabase.from('patient_injuries').select().eq('patient_id', data.patientId!).single();
      expect(injury['affected_side'], 'right');
      expect(injury['affected_joint'], 'elbow');
      expect(injury['injury_type'], 'fracture');
      expect(injury['cause'], 'fall');
      expect(injury['first_injury'], true);
      expect(injury['pain_level'], 2);
      expect(injury['source'], 'patient_self_report');
      print('✓ patient_injuries row');

      expect(supabase.auth.currentUser?.userMetadata?['onboarding'], isNull,
          reason: 'sign-up metadata copy is cleared once registered');
      print('✓ sign-up metadata cleared');

      // --- Wearable ---------------------------------------------------
      data.wearable = _testDevice1;
      data.deviceRecordId = await repo.saveWearable(data.patientId!, data.wearable!);
      final device = await supabase.from('wearable_devices').select().eq('id', data.deviceRecordId!).single();
      expect(device['serial_no'], _testDevice1.id);
      expect(device['status'], 'paired');
      expect(device['firmware_version'], '1.4.2');
      final flag = await supabase.from('patients').select('wearable_connected').eq('id', data.patientId!).single();
      expect(flag['wearable_connected'], true, reason: 'wearable sync trigger');
      print('✓ wearable_devices row + patients.wearable_connected (trigger)');

      // Re-pairing a different band replaces the first one.
      const second = _testDevice2;
      final secondId = await repo.saveWearable(data.patientId!, second);
      final devices =
          await supabase.from('wearable_devices').select('id, status').eq('patient_id', data.patientId!);
      final statuses = {for (final d in devices) d['id']: d['status']};
      expect(statuses[data.deviceRecordId], 'replaced');
      expect(statuses[secondId], 'paired');
      data
        ..wearable = second
        ..deviceRecordId = secondId;
      print('✓ re-pairing marks the old band replaced');

      // --- Calibration baseline ---------------------------------------
      const baseline = BaselineReading(neutral: 3, flexion: 118, extension: 8);
      await repo.saveBaseline(
        patientId: data.patientId!,
        deviceRecordId: data.deviceRecordId,
        baseline: baseline,
        reps: 3,
      );
      final session = await supabase
          .from('sessions')
          .select('rom, reps, device_id, exercise_id, movement_analysis(joint_angle, rom, repetition_count, posture_status)')
          .eq('patient_id', data.patientId!)
          .single();
      expect(session['rom'], 110);
      expect(session['reps'], 3);
      expect(session['device_id'], secondId);
      expect(session['exercise_id'], isNull);
      final analysis = (session['movement_analysis'] as List).single as Map;
      expect(analysis['joint_angle'], 118);
      expect(analysis['rom'], 110);
      expect(analysis['repetition_count'], 3);
      expect(analysis['posture_status'], OnboardingRepository.baselineMarker);
      print('✓ sessions + movement_analysis baseline');

      // --- Clinic / physiotherapist -----------------------------------
      final clinics = await repo.listClinics();
      print('  ${clinics.length} clinic(s) listed');
      Clinic? clinic;
      Physiotherapist? physio;
      for (final c in clinics) {
        final physios = await repo.listPhysiotherapists(c.id);
        if (physios.isNotEmpty) {
          clinic = c;
          physio = physios.first;
          break;
        }
      }
      expect(physio, isNotNull, reason: 'needs at least one clinic with an Active physiotherapist');
      data
        ..clinic = clinic
        ..physio = physio;
      await repo.chooseClinicAndPhysio(clinic!, physio!);
      final chosen = await supabase.from('patients').select('clinic_id, physio_id').eq('id', data.patientId!).single();
      expect(chosen['clinic_id'], clinic.id);
      expect(chosen['physio_id'], physio.id);
      print('✓ clinic "${clinic.name}" + physio "${physio.fullName}"');

      // --- Resume (what AuthGate does on next sign-in) -----------------
      final row = await supabase.from('patients').select().eq('id', data.patientId!).single();
      final restored = await repo.hydrate(row);
      expect(restored.fullName, 'E2E Test Patient');
      expect(restored.affectedJoint, 'elbow');
      expect(restored.painLevel, 2);
      expect(restored.clinic?.id, clinic.id);
      expect(restored.physio?.id, physio.id);
      expect(restored.wearable?.id, second.id);
      expect(restored.baseline?.flexion, 118);
      expect(restored.baseline?.range, 110);
      print('✓ hydrate() restores everything for resume / waiting screen');

      // register_patient_self is idempotent: a retry returns the same row.
      final again = await supabase.rpc('register_patient_self', params: data.registrationParams());
      expect((again as Map)['id'], data.patientId);
      print('✓ register_patient_self retry is idempotent');
    } finally {
      // Runs whenever a login exists — including when sign-up worked but a
      // later step failed — so no test account is left behind.
      if (supabase.auth.currentUser != null) {
        await supabase.rpc('delete_my_account');
        await supabase.auth.signOut();
        print('✓ cleanup: delete_my_account() removed the test account');
        final relogin = supabase.auth.signInWithPassword(email: data.email, password: data.password);
        await expectLater(relogin, throwsA(isA<AuthException>()));
        print('✓ cleanup verified: test login no longer exists');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// In-memory stand-in for the shared_preferences-backed auth storage,
/// which has no platform implementation under flutter test.
class _MemoryAsyncStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}
