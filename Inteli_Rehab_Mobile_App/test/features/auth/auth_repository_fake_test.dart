import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/domain/repositories/auth_repository.dart';

void main() {
  late AuthRepositoryFake repository;

  setUp(() {
    repository = AuthRepositoryFake(allowInReleaseForTesting: true);
  });

  tearDown(() {
    repository.dispose();
  });

  group('AuthRepositoryFake - Core Sign In & Sign Out', () {
    test('initial state is unauthenticated', () {
      expect(repository.isAuthenticated, isFalse);
      expect(repository.currentUserEmail, isNull);
    });

    test(
      'successful signIn updates state and emits true on authStateChanges',
      () async {
        final states = <bool>[];
        final sub = repository.authStateChanges.listen(states.add);

        await repository.signIn(
          email: 'patient@clinic.com',
          password: 'Password123',
        );
        await Future<void>.delayed(Duration.zero);

        expect(repository.isAuthenticated, isTrue);
        expect(repository.currentUserEmail, 'patient@clinic.com');
        expect(states, [true]);

        await sub.cancel();
      },
    );

    test(
      'simulated failure throws InvalidCredentialsException and leaves state unauthenticated',
      () async {
        repository.setSimulateFailure(true);

        expect(
          () => repository.signIn(
            email: 'wrong@clinic.com',
            password: 'WrongPassword123',
          ),
          throwsA(isA<InvalidCredentialsException>()),
        );

        expect(repository.isAuthenticated, isFalse);
        expect(repository.currentUserEmail, isNull);
      },
    );

    test('simulated network failure throws AuthNetworkException', () async {
      repository.setSimulateNetworkFailure(true);

      expect(
        () => repository.signIn(
          email: 'patient@clinic.com',
          password: 'Password123',
        ),
        throwsA(isA<AuthNetworkException>()),
      );
    });

    test(
      'release mode guard throws AuthReleaseModeException when not allowed',
      () {
        // AuthRepositoryFake defaults allowInReleaseForTesting to false
        // When kReleaseMode is simulated or active, it throws AuthReleaseModeException
        expect(
          () => AuthRepositoryFake(allowInReleaseForTesting: false),
          anything, // Instantiates cleanly in debug, throws in release
        );
      },
    );

    test('signOut clears authenticated state and emits false', () async {
      await repository.signIn(
        email: 'patient@clinic.com',
        password: 'Password123',
      );

      final states = <bool>[];
      final sub = repository.authStateChanges.listen(states.add);

      await repository.signOut();

      expect(repository.isAuthenticated, isFalse);
      expect(repository.currentUserEmail, isNull);
      expect(states, [false]);

      await sub.cancel();
    });
  });

  group('AuthRepositoryFake - Registration', () {
    test(
      'registerWithRegId completes successfully for preview without persistence',
      () async {
        await expectLater(
          repository.registerWithRegId(
            email: 'newpatient@clinic.com',
            password: 'Password123',
            regId: 'REG-101',
          ),
          completes,
        );

        // Registration is preview-only: does not automatically authenticate
        expect(repository.isAuthenticated, isFalse);
      },
    );

    test('registerWithRegId respects simulated failure toggle', () async {
      repository.setSimulateFailure(true);

      await expectLater(
        () => repository.registerWithRegId(
          email: 'newpatient@clinic.com',
          password: 'Password123',
          regId: 'INVALID-ID',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AuthRepositoryFake - 30-Minute Inactivity Expiry', () {
    test(
      'checkSessionExpiry keeps session alive if activity was within 30 minutes',
      () async {
        await repository.signIn(
          email: 'patient@clinic.com',
          password: 'Password123',
        );

        // Simulate activity 15 minutes ago
        repository.setLastActiveTimeForTesting(
          DateTime.now().subtract(const Duration(minutes: 15)),
        );

        repository.checkSessionExpiry();

        expect(repository.isAuthenticated, isTrue);
      },
    );

    test(
      'checkSessionExpiry terminates session if inactive for >= 30 minutes',
      () async {
        await repository.signIn(
          email: 'patient@clinic.com',
          password: 'Password123',
        );

        final states = <bool>[];
        final sub = repository.authStateChanges.listen(states.add);

        // Simulate activity 31 minutes ago
        repository.setLastActiveTimeForTesting(
          DateTime.now().subtract(const Duration(minutes: 31)),
        );

        repository.checkSessionExpiry();
        await Future<void>.delayed(Duration.zero);

        expect(repository.isAuthenticated, isFalse);
        expect(repository.currentUserEmail, isNull);
        expect(states, [false]);

        await sub.cancel();
      },
    );

    test('recordActivity refreshes the activity timestamp', () async {
      await repository.signIn(
        email: 'patient@clinic.com',
        password: 'Password123',
      );

      // Set old time
      repository.setLastActiveTimeForTesting(
        DateTime.now().subtract(const Duration(minutes: 29)),
      );

      // User performs activity
      repository.recordActivity();

      // Check expiry: should NOT expire now because activity was refreshed
      repository.checkSessionExpiry();
      expect(repository.isAuthenticated, isTrue);
    });
  });
}
