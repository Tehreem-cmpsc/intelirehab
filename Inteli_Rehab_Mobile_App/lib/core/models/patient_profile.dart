class PatientProfile {
  final String id;
  final String name;
  final String? injury;
  final String status;
  final bool approved;
  final String? warning;

  const PatientProfile({
    required this.id,
    required this.name,
    required this.status,
    required this.approved,
    this.injury,
    this.warning,
  });

  factory PatientProfile.fromMap(Map<String, dynamic> map) {
    return PatientProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      injury: map['injury'] as String?,
      status: map['status'] as String? ?? 'active',
      approved: map['approved'] as bool? ?? false,
      warning: map['warning'] as String?,
    );
  }
}
