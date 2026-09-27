import '../../domain/entities/calibration_data_entity.dart';
import '../../domain/repositories/sensor_calibration_repository.dart';
import '../datasources/sensor_calibration_data_source.dart';

class SensorCalibrationRepositoryImpl implements SensorCalibrationRepository {
  final SensorCalibrationDataSource dataSource;

  const SensorCalibrationRepositoryImpl(this.dataSource);

  @override
  Future<CalibrationDataEntity> calibrate() {
    return dataSource.calibrate();
  }
}
