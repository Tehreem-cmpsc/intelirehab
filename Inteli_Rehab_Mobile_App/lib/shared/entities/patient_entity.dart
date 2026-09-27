import '../enums/injury_type.dart';

class PatientEntity {
  final String id;
  final String name;
  final String email;
  final String? clinicId;
  final String? physiotherapistId;
  final InjuryType injuryType;
  final String affectedJoint;
  final double recoveryPercentage;
  final int streakDays;

  const PatientEntity({
    required this.id,
    required this.name,
    required this.email,
    this.clinicId,
    this.physiotherapistId,
    this.injuryType = InjuryType.other,
    this.affectedJoint = 'Shoulder',
    this.recoveryPercentage = 0.0,
    this.streakDays = 0,
  });
}
