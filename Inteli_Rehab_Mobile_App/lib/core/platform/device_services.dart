import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper over the `inteli_rehab/device` channel in MainActivity.kt.
/// Every call degrades gracefully: on platforms without the channel (iOS,
/// tests) battery is unknown (no warning shown) and storage falls back to
/// the system temp directory.
class DeviceServices {
  static const _channel = MethodChannel('inteli_rehab/device');

  /// The phone's battery %, or null if it can't be read.
  static Future<int?> phoneBattery() async {
    try {
      return await _channel.invokeMethod<int>('phoneBattery');
    } catch (_) {
      return null;
    }
  }

  static Directory? _filesDir;

  /// Durable app-private storage (survives process death, unlike a cache).
  static Future<Directory> filesDir() async {
    if (_filesDir != null) return _filesDir!;
    try {
      final path = await _channel.invokeMethod<String>('filesDir');
      if (path != null) return _filesDir = Directory(path);
    } catch (_) {
      // Fall through to the temp directory.
    }
    return _filesDir = Directory.systemTemp;
  }
}
