abstract class SensorCalibrationState {
  const SensorCalibrationState();
}

class SensorCalibrationInitial extends SensorCalibrationState {
  const SensorCalibrationInitial();
}

class SensorCalibrating extends SensorCalibrationState {
  final double progress;
  const SensorCalibrating(this.progress);
}

class SensorCalibrationSuccess extends SensorCalibrationState {
  const SensorCalibrationSuccess();
}

class SensorCalibrationError extends SensorCalibrationState {
  final String message;
  const SensorCalibrationError(this.message);
}
