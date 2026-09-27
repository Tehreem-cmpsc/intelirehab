import '../models/calibration_data_model.dart';

abstract class SensorCalibrationDataSource {
  Future<CalibrationDataModel> calibrate();
}

class SensorCalibrationDataSourceImpl implements SensorCalibrationDataSource {
  @override
  Future<CalibrationDataModel> calibrate() async {
    return const CalibrationDataModel(
      neutralJointAngle: 0.0,
      restingEmgBaseline: 0.0,
      isCalibrated: true,
    );
  }
}
