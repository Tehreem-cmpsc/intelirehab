import 'sensor_calibration_state.dart';

class SensorCalibrationCubit {
  SensorCalibrationState _state = const SensorCalibrationInitial();
  SensorCalibrationState get state => _state;

  void emit(SensorCalibrationState newState) {
    _state = newState;
  }

  void startCalibration() {}
}
