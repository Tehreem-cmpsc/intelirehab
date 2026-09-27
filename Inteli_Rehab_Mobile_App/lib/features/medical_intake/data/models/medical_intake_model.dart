import '../../domain/entities/medical_intake_entity.dart';

class MedicalIntakeModel extends MedicalIntakeEntity {
  const MedicalIntakeModel({
    required super.patientId,
    required super.affectedJoint,
    required super.injuryType,
    required super.notes,
  });

  factory MedicalIntakeModel.fromJson(Map<String, dynamic> json) {
    return MedicalIntakeModel(
      patientId: json['patientId'] as String? ?? '',
      affectedJoint: json['affectedJoint'] as String? ?? '',
      injuryType: json['injuryType'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'affectedJoint': affectedJoint,
      'injuryType': injuryType,
      'notes': notes,
    };
  }
}
