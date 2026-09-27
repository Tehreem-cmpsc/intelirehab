import '../../domain/entities/wearable_device_entity.dart';
import '../../domain/repositories/wearable_repository.dart';
import '../datasources/wearable_ble_data_source.dart';

class WearableRepositoryImpl implements WearableRepository {
  final WearableBleDataSource bleDataSource;

  const WearableRepositoryImpl(this.bleDataSource);

  @override
  Stream<List<WearableDeviceEntity>> scanDevices() {
    return bleDataSource.scanDevices();
  }

  @override
  Future<void> connect(String deviceId) {
    return bleDataSource.connect(deviceId);
  }

  @override
  Future<void> disconnect() {
    return bleDataSource.disconnect();
  }
}
