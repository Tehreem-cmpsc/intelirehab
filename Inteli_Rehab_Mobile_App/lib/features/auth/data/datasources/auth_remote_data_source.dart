import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/patient_profile.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String email, String password, String name);
  Future<void> logout();
}

/// Thin service handling Supabase auth & patient profile claims.
/// Directly implements Tehreem's backend calls from Inteli_Rehab_Mobile_App.
class AuthService implements AuthRemoteDataSource {
  Stream<AuthState> get onAuthStateChange => supabase.auth.onAuthStateChange;

  Session? get currentSession => supabase.auth.currentSession;
  User? get currentUser => supabase.auth.currentUser;

  @override
  Future<UserModel> login(String email, String password) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    return UserModel(
      id: user?.id ?? '',
      email: user?.email ?? email,
      name: user?.userMetadata?['name'] as String? ?? 'Patient',
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserModel> register(String email, String password, String name) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    final user = response.user;
    return UserModel(
      id: user?.id ?? '',
      email: user?.email ?? email,
      name: name,
    );
  }

  /// Two-step registration (Tehreem's backend flow):
  /// 1. Create Supabase Auth user
  /// 2. Link auth user to existing clinic patient record using 'claim_patient_record' RPC
  Future<void> registerWithRegId({
    required String email,
    required String password,
    required String regId,
  }) async {
    final signUpResponse = await supabase.auth.signUp(
      email: email,
      password: password,
    );
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

  @override
  Future<void> logout() => signOut();

  Future<void> signOut() => supabase.auth.signOut();

  Future<PatientProfile?> fetchMyPatientProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await supabase
        .from('patients')
        .select()
        .eq('user_id', uid)
        .maybeSingle();

    if (row == null) return null;
    return PatientProfile.fromMap(row);
  }
}
