import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/entities/patient_entity.dart';

/// Thin service handling Supabase auth & patient profile claims.
/// Directly implements Tehreem's backend calls from Inteli_Rehab_Mobile_App.
class AuthService {
  Stream<AuthState> get onAuthStateChange => supabase.auth.onAuthStateChange;

  Session? get currentSession => supabase.auth.currentSession;
  User? get currentUser => supabase.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registers user and links clinic record via claim_patient_record RPC.
  Future<void> registerWithRegId({
    required String email,
    required String password,
    required String regId,
  }) async {
    final authRes = await supabase.auth.signUp(
      email: email,
      password: password,
    );
    final user = authRes.user;
    if (user == null) {
      throw Exception('Registration failed: no user returned from auth server.');
    }

    try {
      await supabase.rpc('claim_patient_record', params: {
        'target_reg_id': regId,
      });
    } catch (_) {
      throw Exception(
        'Account was created, but your registration ID could not be '
        'linked (it may be incorrect or already used). Contact your clinic — '
        'do not try registering again with this email.',
      );
    }
  }

  Future<void> logout() => signOut();

  Future<void> signOut() => supabase.auth.signOut();

  Future<PatientEntity?> fetchMyPatientProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('patients')
        .select()
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null) return null;
    return PatientEntity.fromMap(row);
  }
}
