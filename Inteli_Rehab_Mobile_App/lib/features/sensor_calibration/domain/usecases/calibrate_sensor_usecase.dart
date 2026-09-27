import '../entities/calibration_data_entity.dart';
import '../repositories/sensor_calibration_repository.dart';

class CalibrateSensorUsecase {
  final SensorCalibrationRepository repository;
  const CalibrateSensorUsecase(this.repository);

  Future<CalibrationDataEntity> call() {
    return repository.calibrate();
  }
}
