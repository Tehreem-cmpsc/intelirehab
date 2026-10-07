import 'dart:io';
import 'package:flutter/foundation.dart';

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

  /// Keeps the screen on (or lets it sleep again). Best effort: a failure just means the normal
  /// screen timeout applies.
  static Future<void> keepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
    } catch (_) {}
  }

  /// Says [text] aloud through the phone's text-to-speech, replacing anything still being said.
  /// Best effort and silent on platforms without it.
  static Future<void> speak(String text) async {
    try {
      await _channel.invokeMethod<void>('speak', text);
    } catch (_) {}
  }

  static Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod<void>('stopSpeaking');
    } catch (_) {}
  }

  static Directory? _filesDir;

  /// Tests: give each test file its own storage folder, so files that use the session journal can run
  /// in parallel without sharing (and overwriting) one journal file.
  @visibleForTesting
  static void overrideFilesDir(Directory dir) => _filesDir = dir;

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
