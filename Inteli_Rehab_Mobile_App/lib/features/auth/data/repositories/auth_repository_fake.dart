import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

/// Fake auth repository — returns dummy data while Tehreem builds the real backend.
/// DO NOT delete: Kashmala owns this. Tehreem edits auth_repository_impl.dart instead.
class AuthRepositoryFake implements AuthRepository {
  @override
  Future<UserEntity> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Return a dummy patient user — valid for any email/password
    return const UserEntity(
      id: 'fake-patient-001',
      email: 'kashmala.patient@test.com',
      name: 'Kashmala (Test Patient)',
    );
  }

  @override
  Future<UserEntity> register(String email, String password, String name) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return UserEntity(
      id: 'fake-patient-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
    );
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // No-op in fake implementation
  }
}
