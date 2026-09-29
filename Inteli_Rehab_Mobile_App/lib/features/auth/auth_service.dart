import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';

/// Thin wrapper around the Supabase auth calls the patient app needs.
/// Account creation lives in OnboardingRepository.createAccount, since it
/// is one step of onboarding.
class AuthService {
  Stream<AuthState> get onAuthStateChange => supabase.auth.onAuthStateChange;

  Session? get currentSession => supabase.auth.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => supabase.auth.signOut();

  /// The signed-in user's patients row, or null if registration hasn't
  /// completed yet (e.g. email confirmation delayed it).
  Future<Map<String, dynamic>?> fetchMyPatientRow() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    return supabase.from('patients').select().eq('user_id', uid).maybeSingle();
  }

  /// The patient's currently paired band, if any — used to seed the Home
  /// screen's wearable status chip before it's connected live.
  Future<Map<String, dynamic>?> fetchPairedDevice(String patientId) {
    return supabase
        .from('wearable_devices')
        .select('serial_no')
        .eq('patient_id', patientId)
        .eq('status', 'paired')
        .maybeSingle();
  }
}
