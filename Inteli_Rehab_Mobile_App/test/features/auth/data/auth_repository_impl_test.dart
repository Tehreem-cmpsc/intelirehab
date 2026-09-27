import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';

void main() {
  late AuthRepositoryFake fakeRepo;

  setUp(() {
    fakeRepo = AuthRepositoryFake();
  });

  group('AuthRepositoryFake', () {
    test('login returns a UserEntity with the correct email', () async {
      final user = await fakeRepo.login('test@example.com', 'password123');
      expect(user.email, equals('kashmala.patient@test.com'));
      expect(user.id, isNotEmpty);
      expect(user.name, isNotEmpty);
    });

    test('register returns a UserEntity with the provided name and email', () async {
      final user = await fakeRepo.register('new@example.com', 'pass', 'Test User');
      expect(user.email, equals('new@example.com'));
      expect(user.name, equals('Test User'));
      expect(user.id, isNotEmpty);
    });

    test('logout completes without error', () async {
      await expectLater(fakeRepo.logout(), completes);
    });
  });
}
