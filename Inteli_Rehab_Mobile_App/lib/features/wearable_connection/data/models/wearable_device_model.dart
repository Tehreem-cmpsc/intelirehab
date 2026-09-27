import '../../domain/entities/wearable_device_entity.dart';

class WearableDeviceModel extends WearableDeviceEntity {
  const WearableDeviceModel({
    required super.id,
    required super.name,
    required super.batteryLevel,
    required super.isConnected,
  });

  factory WearableDeviceModel.fromJson(Map<String, dynamic> json) {
    return WearableDeviceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      batteryLevel: json['batteryLevel'] as int? ?? 0,
      isConnected: json['isConnected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'batteryLevel': batteryLevel,
      'isConnected': isConnected,
    };
  }
}
