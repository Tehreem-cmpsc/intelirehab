import '../entities/calibration_data_entity.dart';

abstract class SensorCalibrationRepository {
  Future<CalibrationDataEntity> calibrate();
}
