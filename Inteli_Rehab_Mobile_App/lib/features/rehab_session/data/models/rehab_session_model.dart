import '../../domain/entities/rehab_session_entity.dart';

class RehabSessionModel extends RehabSessionEntity {
  const RehabSessionModel({
    required super.id,
    required super.exerciseId,
    required super.completedReps,
    required super.maxRom,
    required super.averageScore,
    required super.timestamp,
  });

  factory RehabSessionModel.fromJson(Map<String, dynamic> json) {
    return RehabSessionModel(
      id: json['id'] as String? ?? '',
      exerciseId: json['exerciseId'] as String? ?? '',
      completedReps: json['completedReps'] as int? ?? 0,
      maxRom: (json['maxRom'] as num?)?.toDouble() ?? 0.0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'completedReps': completedReps,
      'maxRom': maxRom,
      'averageScore': averageScore,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
