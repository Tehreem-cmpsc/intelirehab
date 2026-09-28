import 'package:flutter/material.dart';

/// Everything the patient enters across the onboarding flow.
///
/// Option `value`s match the check constraints in
/// supabase_patient_onboarding_v2.sql, so [registrationParams] is a
/// straight mapping onto register_patient_self().
class OnboardingData extends ChangeNotifier {
  // Server-side ids, filled in as each step is saved.
  String? patientId;
  String? deviceRecordId;
  bool baselineSaved = false;

  // Personal details
  String fullName = '';
  DateTime? dateOfBirth;
  String? gender;
  String? activityLevel;
  String? dominantArm;

  // Injury details
  String? affectedSide;
  String? affectedJoint;
  String? injuryType;
  String? injuryCause;
  DateTime? injuryDate;
  bool? firstInjury;
  int? painLevel;

  // Contact
  String phone = '';
  String email = '';
  String password = '';
  bool termsAccepted = false;

  // Clinic / physiotherapist
  Clinic? clinic;
  Physiotherapist? physio;

  // Wearable
  WearableDevice? wearable;
  bool wearableSkipped = false;

  // Calibration
  BaselineReading? baseline;
  bool calibrationSkipped = false;

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  bool get personalChoicesComplete =>
      dateOfBirth != null && gender != null && activityLevel != null && dominantArm != null;

  bool get injuryChoicesComplete =>
      affectedSide != null &&
      affectedJoint != null &&
      injuryType != null &&
      injuryCause != null &&
      injuryDate != null &&
      firstInjury != null &&
      painLevel != null;

  /// Arguments for register_patient_self (v2). Also stored in the auth
  /// user's metadata at sign-up, so registration can finish on first
  /// sign-in if the project requires email confirmation.
  Map<String, dynamic> registrationParams() => {
        'p_name': fullName.trim(),
        'p_phone': phone.trim(),
        'p_date_of_birth': _isoDate(dateOfBirth),
        'p_gender': gender,
        'p_activity_level': activityLevel,
        'p_dominant_arm': dominantArm,
        'p_affected_side': affectedSide,
        'p_affected_joint': affectedJoint,
        'p_injury_type': injuryType,
        'p_injury_cause': injuryCause,
        'p_injury_date': _isoDate(injuryDate),
        'p_first_injury': firstInjury,
        'p_pain_level': painLevel,
      };

  static String? _isoDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get sideLabel => labelFor(sideOptions, affectedSide)?.toLowerCase() ?? 'injured';
  String get jointLabel => labelFor(jointOptions, affectedJoint)?.toLowerCase() ?? 'arm';
}

class Option {
  final String value;
  final String label;
  final String? caption;
  final IconData? icon;
  const Option(this.value, this.label, {this.caption, this.icon});
}

String? labelFor(List<Option> options, String? value) {
  for (final o in options) {
    if (o.value == value) return o.label;
  }
  return null;
}

const genderOptions = [
  Option('male', 'Male'),
  Option('female', 'Female'),
  Option('other', 'Other'),
  Option('prefer_not_to_say', 'Prefer not to say'),
];

const activityOptions = [
  Option('sedentary', 'Sedentary', caption: 'Mostly sitting', icon: Icons.weekend_outlined),
  Option('light', 'Light', caption: 'Walks, light chores', icon: Icons.directions_walk),
  Option('active', 'Active', caption: 'Exercise 3–4× a week', icon: Icons.directions_run),
  Option('very_active', 'Very active', caption: 'Sport or physical job', icon: Icons.fitness_center),
];

const dominantArmOptions = [
  Option('left', 'Left'),
  Option('right', 'Right'),
  Option('both', 'Both'),
];

const sideOptions = [
  Option('left', 'Left arm'),
  Option('right', 'Right arm'),
];

const jointOptions = [
  Option('upper_arm', 'Upper arm'),
  Option('elbow', 'Elbow'),
  Option('forearm', 'Forearm'),
];

const injuryTypeOptions = [
  Option('muscle_strain', 'Muscle strain', icon: Icons.fitness_center),
  Option('tendon', 'Tendon', icon: Icons.linear_scale),
  Option('joint', 'Joint', icon: Icons.join_inner),
  Option('fracture', 'Fracture', icon: Icons.healing),
  Option('post_surgery', 'After surgery', icon: Icons.medical_services_outlined),
  Option('other', 'Other / not sure', icon: Icons.help_outline),
];

const injuryCauseOptions = [
  Option('sports', 'Sports', icon: Icons.sports_tennis),
  Option('fall', 'A fall', icon: Icons.personal_injury_outlined),
  Option('accident', 'Accident', icon: Icons.car_crash_outlined),
  Option('overuse', 'Overuse', icon: Icons.repeat),
  Option('surgery', 'Surgery', icon: Icons.local_hospital_outlined),
  Option('other', 'Other', icon: Icons.more_horiz),
];

const painOptions = [
  Option('0', 'None'),
  Option('1', 'Mild'),
  Option('2', 'Moderate'),
  Option('3', 'Severe'),
];

class Clinic {
  final String id;
  final String name;
  final String address;
  const Clinic(this.id, this.name, this.address);

  /// A row from list_onboarding_clinics().
  factory Clinic.fromMap(Map<String, dynamic> m) =>
      Clinic(m['id'] as String, m['name'] as String? ?? 'Clinic', m['address'] as String? ?? '');
}

class Physiotherapist {
  final String id;
  final String clinicId;
  final String fullName;
  final String? specialization;
  final int? yearsExperience;
  const Physiotherapist(this.id, this.clinicId, this.fullName, this.specialization, this.yearsExperience);

  /// A row from list_clinic_physiotherapists(clinicId).
  factory Physiotherapist.fromMap(String clinicId, Map<String, dynamic> m) => Physiotherapist(
        m['id'] as String,
        clinicId,
        m['full_name'] as String? ?? 'Physiotherapist',
        m['specialization'] as String?,
        (m['years_experience'] as num?)?.toInt(),
      );

  String get initials {
    final parts = fullName.replaceFirst(RegExp(r'^Dr\.?\s*'), '').split(' ').where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }
}

class WearableDevice {
  /// The band's serial — stored as wearable_devices.serial_no.
  final String id;
  final String name;
  final int signal; // 0–3 bars
  final int? battery; // %, only known while connected
  final String? firmware;
  final String? macAddress;
  const WearableDevice(this.id, this.name, this.signal, this.battery, {this.firmware, this.macAddress});
}

class BaselineReading {
  final int neutral;
  final int flexion;
  final int extension;
  const BaselineReading({required this.neutral, required this.flexion, required this.extension});

  int get range => flexion - extension;
}
