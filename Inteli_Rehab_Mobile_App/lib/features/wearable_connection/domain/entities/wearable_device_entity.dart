class WearableDeviceEntity {
  final String id;
  final String name;
  final int batteryLevel;
  final bool isConnected;

  const WearableDeviceEntity({
    required this.id,
    required this.name,
    required this.batteryLevel,
    required this.isConnected,
  });
}
