import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUsecase {
  final AuthRepository repository;
  const RegisterUsecase(this.repository);

  Future<UserEntity> call(String email, String password, String name) {
    return repository.register(email, password, name);
  }
}
