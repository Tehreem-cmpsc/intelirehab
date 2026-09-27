class MedicalIntakeEntity {
  final String patientId;
  final String affectedJoint;
  final String injuryType;
  final String notes;

  const MedicalIntakeEntity({
    required this.patientId,
    required this.affectedJoint,
    required this.injuryType,
    required this.notes,
  });
}
