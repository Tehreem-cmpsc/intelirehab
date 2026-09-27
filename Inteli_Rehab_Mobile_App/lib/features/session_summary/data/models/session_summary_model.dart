import '../../domain/entities/session_summary_entity.dart';

class SessionSummaryModel extends SessionSummaryEntity {
  const SessionSummaryModel({
    required super.sessionId,
    required super.completedReps,
    required super.movementQuality,
    required super.romImproved,
    required super.consistencyScore,
  });

  factory SessionSummaryModel.fromJson(Map<String, dynamic> json) {
    return SessionSummaryModel(
      sessionId: json['sessionId'] as String? ?? '',
      completedReps: json['completedReps'] as int? ?? 0,
      movementQuality: json['movementQuality'] as String? ?? '',
      romImproved: (json['romImproved'] as num?)?.toDouble() ?? 0.0,
      consistencyScore: json['consistencyScore'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'completedReps': completedReps,
      'movementQuality': movementQuality,
      'romImproved': romImproved,
      'consistencyScore': consistencyScore,
    };
  }
}
