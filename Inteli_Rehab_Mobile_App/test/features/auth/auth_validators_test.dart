import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/features/auth/presentation/validators/auth_validators.dart';

void main() {
  group('AuthValidators - Email', () {
    test('rejects null or empty email with actionable error message', () {
      expect(AuthValidators.validateEmail(null), 'Enter your email address.');
      expect(AuthValidators.validateEmail(''), 'Enter your email address.');
      expect(AuthValidators.validateEmail('   '), 'Enter your email address.');
    });

    test('rejects email missing @ symbol', () {
      expect(
        AuthValidators.validateEmail('patientclinic.com'),
        'Enter an email address such as you@example.com.',
      );
    });

    test('rejects malformed email formats', () {
      expect(
        AuthValidators.validateEmail('patient@'),
        'Enter an email address such as you@example.com.',
      );
      expect(
        AuthValidators.validateEmail('@clinic.com'),
        'Enter an email address such as you@example.com.',
      );
      expect(
        AuthValidators.validateEmail('patient@clinic'),
        'Enter an email address such as you@example.com.',
      );
    });

    test('accepts valid email addresses', () {
      expect(AuthValidators.validateEmail('patient@clinic.com'), isNull);
      expect(AuthValidators.validateEmail('ayesha.k@intelirehab.org'), isNull);
      expect(
        AuthValidators.validateEmail('  dr.tehreem@ayub.med.pk  '),
        isNull,
      );
    });

    test('normalizeEmail trims and lowercases email', () {
      expect(
        AuthValidators.normalizeEmail('  Ayesha.Khan@Clinic.COM  '),
        'ayesha.khan@clinic.com',
      );
      expect(AuthValidators.normalizeEmail(null), '');
    });
  });

  group('AuthValidators - Password', () {
    test('rejects null or empty password', () {
      expect(AuthValidators.validatePassword(null), 'Enter your password.');
      expect(AuthValidators.validatePassword(''), 'Enter your password.');
      expect(AuthValidators.validateLoginPassword(''), 'Enter your password.');
    });

    test('rejects registration password shorter than 8 characters', () {
      expect(
        AuthValidators.validateRegisterPassword('1234567'),
        'Password must be at least 8 characters long.',
      );
    });

    test(
      'accepts password of 8 or more characters without altering content',
      () {
        expect(AuthValidators.validateRegisterPassword('12345678'), isNull);
        expect(AuthValidators.validateRegisterPassword('  spaces  '), isNull);
        expect(AuthValidators.validateRegisterPassword('P@ssw0rd!'), isNull);
      },
    );

    test('login password validation allows existing non-empty password', () {
      expect(AuthValidators.validateLoginPassword('short'), isNull);
      expect(AuthValidators.validateLoginPassword('12345678'), isNull);
    });
  });

  group('AuthValidators - Clinic Registration ID', () {
    test('rejects null, empty, or whitespace-only regId', () {
      expect(
        AuthValidators.validateClinicRegId(null),
        'Enter your clinic registration ID.',
      );
      expect(
        AuthValidators.validateClinicRegId(''),
        'Enter your clinic registration ID.',
      );
      expect(
        AuthValidators.validateClinicRegId('   '),
        'Enter your clinic registration ID.',
      );
    });

    test('rejects regId shorter than 3 characters', () {
      expect(
        AuthValidators.validateClinicRegId('AB'),
        'Registration ID must be at least 3 characters long.',
      );
    });

    test('rejects regId longer than 20 characters', () {
      expect(
        AuthValidators.validateClinicRegId('REG-12345678901234567'), // 21 chars
        'Registration ID cannot exceed 20 characters.',
      );
    });

    test('rejects regId with invalid special characters', () {
      expect(
        AuthValidators.validateClinicRegId('REG#101!'),
        'Registration ID may only contain letters, numbers, hyphens, and underscores.',
      );
    });

    test('accepts valid clinic registration IDs and boundary lengths', () {
      // 3 characters minimum boundary
      expect(AuthValidators.validateClinicRegId('R-1'), isNull);
      expect(AuthValidators.validateClinicRegId('R_1'), isNull);
      // Typical formats
      expect(AuthValidators.validateClinicRegId('REG-101'), isNull);
      expect(AuthValidators.validateClinicRegId('AMC-004'), isNull);
      expect(AuthValidators.validateClinicRegId('PAT2026'), isNull);
      expect(AuthValidators.validateClinicRegId('CLI_2026_A'), isNull);
      // 20 characters maximum boundary
      expect(
        AuthValidators.validateClinicRegId('12345678901234567890'),
        isNull,
      );
    });
  });

  group('AuthValidators - Form Validity Checks', () {
    test(
      'isLoginFormValid returns true only when both email and password are valid',
      () {
        expect(
          AuthValidators.isLoginFormValid(email: '', password: ''),
          isFalse,
        );
        expect(
          AuthValidators.isLoginFormValid(
            email: 'patient@clinic.com',
            password: '',
          ),
          isFalse,
        );
        expect(
          AuthValidators.isLoginFormValid(
            email: 'patient@clinic.com',
            password: 'short',
          ),
          isTrue,
        );
        expect(
          AuthValidators.isLoginFormValid(
            email: 'bademail',
            password: 'validpassword123',
          ),
          isFalse,
        );
        expect(
          AuthValidators.isLoginFormValid(
            email: 'patient@clinic.com',
            password: 'validpassword123',
          ),
          isTrue,
        );
      },
    );

    test(
      'isRegisterFormValid returns true only when regId, email, and password are valid',
      () {
        expect(
          AuthValidators.isRegisterFormValid(
            regId: 'REG-101',
            email: 'patient@clinic.com',
            password: 'validpassword123',
          ),
          isTrue,
        );
        expect(
          AuthValidators.isRegisterFormValid(
            regId: 'REG-101',
            email: 'patient@clinic.com',
            password: 'short',
          ),
          isFalse,
        );
        expect(
          AuthValidators.isRegisterFormValid(
            regId: 'X',
            email: 'patient@clinic.com',
            password: 'validpassword123',
          ),
          isFalse,
        );
      },
    );
  });
}
