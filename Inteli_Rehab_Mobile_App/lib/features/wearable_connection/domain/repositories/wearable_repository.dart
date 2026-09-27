import '../entities/wearable_device_entity.dart';

abstract class WearableRepository {
  Stream<List<WearableDeviceEntity>> scanDevices();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
}
