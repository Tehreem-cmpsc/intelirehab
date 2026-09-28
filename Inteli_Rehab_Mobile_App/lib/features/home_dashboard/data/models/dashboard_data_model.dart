import '../../domain/entities/dashboard_data_entity.dart';

class DashboardDataModel extends DashboardDataEntity {
  const DashboardDataModel({
    required super.patientName,
    required super.assignedExercise,
    required super.streakDays,
    required super.recoveryPercentage,
  });

  factory DashboardDataModel.fromJson(Map<String, dynamic> json) {
    return DashboardDataModel(
      patientName: json['patientName'] as String? ?? '',
      assignedExercise: json['assignedExercise'] as String? ?? '',
      streakDays: json['streakDays'] as int? ?? 0,
      recoveryPercentage:
          (json['recoveryPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientName': patientName,
      'assignedExercise': assignedExercise,
      'streakDays': streakDays,
      'recoveryPercentage': recoveryPercentage,
    };
  }
}
