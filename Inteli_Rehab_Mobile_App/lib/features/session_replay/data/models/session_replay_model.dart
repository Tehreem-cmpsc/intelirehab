import '../../domain/entities/session_replay_entity.dart';

class SessionReplayModel extends SessionReplayEntity {
  const SessionReplayModel({
    required super.sessionId,
    required super.angleFrames,
    required super.totalDuration,
  });

  factory SessionReplayModel.fromJson(Map<String, dynamic> json) {
    return SessionReplayModel(
      sessionId: json['sessionId'] as String? ?? '',
      angleFrames: (json['angleFrames'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      totalDuration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'angleFrames': angleFrames,
      'durationSeconds': totalDuration.inSeconds,
    };
  }
}
