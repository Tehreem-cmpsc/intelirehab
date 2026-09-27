import '../entities/wearable_device_entity.dart';
import '../repositories/wearable_repository.dart';

class ScanWearablesUsecase {
  final WearableRepository repository;
  const ScanWearablesUsecase(this.repository);

  Stream<List<WearableDeviceEntity>> call() {
    return repository.scanDevices();
  }
}
