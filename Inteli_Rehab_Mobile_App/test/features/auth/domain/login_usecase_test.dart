import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/domain/usecases/login_usecase.dart';

void main() {
  late LoginUsecase loginUsecase;

  setUp(() {
    loginUsecase = LoginUsecase(AuthRepositoryFake());
  });

  group('LoginUsecase', () {
    test('returns a valid UserEntity on success', () async {
      final user = await loginUsecase.call('any@email.com', 'anypassword');
      expect(user.id, isNotEmpty);
      expect(user.email, isNotEmpty);
      expect(user.name, isNotEmpty);
    });

    test('resolves without throwing for any credentials', () async {
      await expectLater(loginUsecase.call('x@y.com', '1234'), completes);
    });
  });
}
