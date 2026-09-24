import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/patient_profile.dart';
import '../../core/network/supabase_client.dart';

/// Thin wrapper around the Supabase calls the patient app needs.
/// Keeping these out of the widgets makes the screens testable and keeps
/// the "two-step registration" (auth signUp + claim_patient_record) in one
/// place instead of duplicated across screens.
class AuthService {
  Stream<AuthState> get onAuthStateChange => supabase.auth.onAuthStateChange;

  Session? get currentSession => supabase.auth.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Creates the patient's login, then links it to the patient record a
  /// physio already created (see supabase_patient_self_registration.sql).
  /// Both steps must succeed — if the claim fails (bad or already-used
  /// registration ID), the auth account still exists but is left
  /// unlinked; the caller should surface that clearly rather than retry
  /// signUp, which would just fail as "already registered".
  Future<void> registerWithRegId({
    required String email,
    required String password,
    required String regId,
  }) async {
    final signUpResponse = await supabase.auth.signUp(email: email, password: password);
    if (signUpResponse.user == null) {
      throw const AuthException('Could not create your account.');
    }

    try {
      await supabase.rpc('claim_patient_record', params: {'target_reg_id': regId});
    } catch (e) {
      throw Exception(
        'Your account was created, but the registration ID "$regId" could not be '
        'linked (it may be incorrect or already used). Contact your clinic — '
        'do not try registering again with this email.',
      );
    }
  }

  Future<void> signOut() => supabase.auth.signOut();

  /// Null means the signed-in user has no patients row linked yet —
  /// shouldn't normally happen once registerWithRegId succeeds, but is
  /// possible if the claim step failed partway.
  Future<PatientProfile?> fetchMyPatientProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase.from('patients').select().eq('user_id', uid).maybeSingle();
    if (row == null) return null;
    return PatientProfile.fromMap(row);
  }
}
