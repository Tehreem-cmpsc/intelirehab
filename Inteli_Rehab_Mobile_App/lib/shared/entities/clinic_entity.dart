class ClinicEntity {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final String? email;

  const ClinicEntity({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.email,
  });
}
