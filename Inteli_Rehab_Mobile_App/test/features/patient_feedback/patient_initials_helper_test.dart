import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/features/patient_feedback/presentation/utils/patient_initials_helper.dart';

void main() {
  group('PatientInitialsHelper', () {
    test('extracts initials for standard two-word names', () {
      expect(PatientInitialsHelper.extract('Ayesha K.'), 'AK');
      expect(PatientInitialsHelper.extract('Ahmed R.'), 'AR');
      expect(PatientInitialsHelper.extract('Sana M.'), 'SM');
    });

    test('extracts single initial for single-word names', () {
      expect(PatientInitialsHelper.extract('Ayesha'), 'A');
      expect(PatientInitialsHelper.extract('bilal'), 'B');
    });

    test('extracts first and last initials for multi-word names', () {
      expect(PatientInitialsHelper.extract('Mary Jane Watson'), 'MW');
      expect(PatientInitialsHelper.extract('Dr. John Doe Jr.'), 'DJ');
    });

    test('returns fallback "P" for null, empty, or whitespace-only names', () {
      expect(PatientInitialsHelper.extract(null), 'P');
      expect(PatientInitialsHelper.extract(''), 'P');
      expect(PatientInitialsHelper.extract('   '), 'P');
      expect(PatientInitialsHelper.extract('\t\n  '), 'P');
    });

    test('handles Unicode and accented characters accurately', () {
      expect(PatientInitialsHelper.extract('Élise Dupont'), 'ÉD');
      expect(PatientInitialsHelper.extract('Ömer Faruk'), 'ÖF');
    });
  });
}
