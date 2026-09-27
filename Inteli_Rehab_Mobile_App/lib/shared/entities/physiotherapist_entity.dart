class PhysiotherapistEntity {
  final String id;
  final String name;
  final String specialization;
  final String clinicId;
  final String? email;
  final String? phone;

  const PhysiotherapistEntity({
    required this.id,
    required this.name,
    required this.specialization,
    required this.clinicId,
    this.email,
    this.phone,
  });
}
