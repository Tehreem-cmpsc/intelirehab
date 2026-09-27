import '../../domain/entities/physiotherapist_entity.dart';

class PhysiotherapistModel extends PhysiotherapistEntity {
  const PhysiotherapistModel({
    required super.id,
    required super.name,
    required super.specialization,
    required super.clinicId,
  });

  factory PhysiotherapistModel.fromJson(Map<String, dynamic> json) {
    return PhysiotherapistModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      clinicId: json['clinicId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialization': specialization,
      'clinicId': clinicId,
    };
  }
}
