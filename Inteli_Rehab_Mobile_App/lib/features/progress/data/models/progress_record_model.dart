import '../../domain/entities/progress_record_entity.dart';

class ProgressRecordModel extends ProgressRecordEntity {
  const ProgressRecordModel({
    required super.date,
    required super.romDegree,
    required super.completedSessions,
  });

  factory ProgressRecordModel.fromJson(Map<String, dynamic> json) {
    return ProgressRecordModel(
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      romDegree: (json['romDegree'] as num?)?.toDouble() ?? 0.0,
      completedSessions: json['completedSessions'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'romDegree': romDegree,
      'completedSessions': completedSessions,
    };
  }
}
