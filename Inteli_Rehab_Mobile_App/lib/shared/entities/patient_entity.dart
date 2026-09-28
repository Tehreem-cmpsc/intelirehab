import '../enums/injury_type.dart';

/// Unified Patient Entity matching Tehreem's Supabase `patients` schema
/// and Clean Architecture domain requirements.
class PatientEntity {
  final String id;
  final String name;
  final String email;
  final String? clinicId;
  final String? physiotherapistId;
  final String? injury;
  final InjuryType injuryType;
  final String affectedJoint;
  final String status;
  final bool approved;
  final String? warning;
  final double recoveryPercentage;
  final int streakDays;

  const PatientEntity({
    required this.id,
    required this.name,
    this.email = '',
    this.clinicId,
    this.physiotherapistId,
    this.injury,
    this.injuryType = InjuryType.other,
    this.affectedJoint = 'Shoulder',
    this.status = 'active',
    this.approved = false,
    this.warning,
    this.recoveryPercentage = 0.0,
    this.streakDays = 0,
  });

  factory PatientEntity.fromMap(Map<String, dynamic> map) {
    return PatientEntity(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString(),
      physiotherapistId: map['physiotherapist_id']?.toString(),
      injury: map['injury']?.toString(),
      status: map['status']?.toString() ?? 'active',
      approved: map['approved'] as bool? ?? false,
      warning: map['warning']?.toString(),
      recoveryPercentage:
          (map['recovery_percentage'] as num?)?.toDouble() ?? 0.0,
      streakDays: (map['streak_days'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (clinicId != null) 'clinic_id': clinicId,
      if (physiotherapistId != null) 'physiotherapist_id': physiotherapistId,
      'injury': injury,
      'status': status,
      'approved': approved,
      'warning': warning,
      'recovery_percentage': recoveryPercentage,
      'streak_days': streakDays,
    };
  }
}

/// Backward compatibility alias so existing PatientProfile references continue working seamlessly
typedef PatientProfile = PatientEntity;
