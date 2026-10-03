class PatientProfile {
  final String id;
  final String name;
  final String? injury;
  final String status;
  final bool approved;
  final String? warning;

  /// Which arm is being rehabilitated: 'left' or 'right' (patients.injury_side).
  /// Picks the 3D arm model; defaults to left when unknown.
  final String armSide;

  const PatientProfile({
    required this.id,
    required this.name,
    required this.status,
    required this.approved,
    this.injury,
    this.warning,
    this.armSide = 'left',
  });

  factory PatientProfile.fromMap(Map<String, dynamic> map) {
    return PatientProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      injury: map['injury'] as String?,
      status: map['status'] as String? ?? 'active',
      approved: map['approved'] as bool? ?? false,
      warning: map['warning'] as String?,
      armSide: (map['injury_side'] as String?)?.toLowerCase() == 'right' ? 'right' : 'left',
    );
  }
}
