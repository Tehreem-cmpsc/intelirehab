class CalibrationDataEntity {
  final double neutralJointAngle;
  final double restingEmgBaseline;
  final bool isCalibrated;

  const CalibrationDataEntity({
    required this.neutralJointAngle,
    required this.restingEmgBaseline,
    required this.isCalibrated,
  });
}
