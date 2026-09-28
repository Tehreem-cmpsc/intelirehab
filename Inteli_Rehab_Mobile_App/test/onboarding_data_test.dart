import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/onboarding_data.dart';

void main() {
  test('registrationParams matches register_patient_self (v2) arguments', () {
    final data = OnboardingData()
      ..fullName = '  Ayesha Khan '
      ..phone = ' 0300 1234567 '
      ..dateOfBirth = DateTime(1994, 3, 7)
      ..gender = 'female'
      ..activityLevel = 'active'
      ..dominantArm = 'right'
      ..affectedSide = 'right'
      ..affectedJoint = 'elbow'
      ..injuryType = 'fracture'
      ..injuryCause = 'fall'
      ..injuryDate = DateTime(2026, 9, 2)
      ..firstInjury = true
      ..painLevel = 2;

    expect(data.registrationParams(), {
      'p_name': 'Ayesha Khan',
      'p_phone': '0300 1234567',
      'p_date_of_birth': '1994-03-07',
      'p_gender': 'female',
      'p_activity_level': 'active',
      'p_dominant_arm': 'right',
      'p_affected_side': 'right',
      'p_affected_joint': 'elbow',
      'p_injury_type': 'fracture',
      'p_injury_cause': 'fall',
      'p_injury_date': '2026-09-02',
      'p_first_injury': true,
      'p_pain_level': 2,
    });
  });

  test('clinic and physiotherapist rows map from the onboarding RPCs', () {
    final clinic = Clinic.fromMap({'id': 'c1', 'name': 'Abbottabad Rehab', 'address': null});
    expect(clinic.address, '');

    final physio = Physiotherapist.fromMap('c1', {
      'id': 'p1',
      'full_name': 'Dr. Ahmed Khan',
      'specialization': null,
      'years_experience': 12,
    });
    expect(physio.clinicId, 'c1');
    expect(physio.yearsExperience, 12);
    expect(physio.initials, 'AK');
  });
}
