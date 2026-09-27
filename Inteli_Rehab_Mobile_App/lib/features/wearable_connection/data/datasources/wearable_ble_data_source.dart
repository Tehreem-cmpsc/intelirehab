import '../models/wearable_device_model.dart';

abstract class WearableBleDataSource {
  Stream<List<WearableDeviceModel>> scanDevices();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
}

class WearableBleDataSourceImpl implements WearableBleDataSource {
  @override
  Stream<List<WearableDeviceModel>> scanDevices() async* {
    yield [];
  }

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect() async {}
}
