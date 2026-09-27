import '../repositories/wearable_repository.dart';

class ConnectWearableUsecase {
  final WearableRepository repository;
  const ConnectWearableUsecase(this.repository);

  Future<void> call(String deviceId) {
    return repository.connect(deviceId);
  }
}
