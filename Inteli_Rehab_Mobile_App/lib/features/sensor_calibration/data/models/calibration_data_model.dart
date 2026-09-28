import '../../domain/entities/calibration_data_entity.dart';

class CalibrationDataModel extends CalibrationDataEntity {
  const CalibrationDataModel({
    required super.neutralJointAngle,
    required super.restingEmgBaseline,
    required super.isCalibrated,
  });

  factory CalibrationDataModel.fromJson(Map<String, dynamic> json) {
    return CalibrationDataModel(
      neutralJointAngle: (json['neutralJointAngle'] as num?)?.toDouble() ?? 0.0,
      restingEmgBaseline:
          (json['restingEmgBaseline'] as num?)?.toDouble() ?? 0.0,
      isCalibrated: json['isCalibrated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'neutralJointAngle': neutralJointAngle,
      'restingEmgBaseline': restingEmgBaseline,
      'isCalibrated': isCalibrated,
    };
  }
}
