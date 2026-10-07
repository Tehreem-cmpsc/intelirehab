import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/platform/device_services.dart';

/// Spoken cues during a session (rep count, "slow down", "stop"), because the patient's eyes are on
/// their arm, not the screen. On by default; the patient can switch them off from the session screen
/// and the choice is remembered in a small file in app storage.
class SessionCues extends ChangeNotifier {
  static const _fileName = 'session_cues_off';

  final Future<void> Function(String text) _speak;
  final Future<void> Function() _stop;
  bool _enabled = true;

  SessionCues({Future<void> Function(String text)? speak, Future<void> Function()? stop})
      : _speak = speak ?? DeviceServices.speak,
        _stop = stop ?? DeviceServices.stopSpeaking;

  bool get enabled => _enabled;

  /// Reads the remembered choice. A missing or unreadable file just means "on".
  Future<void> load() async {
    try {
      final dir = await DeviceServices.filesDir();
      final off = await File('${dir.path}${Platform.pathSeparator}$_fileName').exists();
      if (off && _enabled) {
        _enabled = false;
        notifyListeners();
      }
    } catch (_) {}
  }

  // Saves go one after another, so switching off and straight back on can never leave the file
  // saying the opposite of what the patient last chose.
  Future<void> _saved = Future.value();

  Future<void> setEnabled(bool on) async {
    if (on == _enabled) return;
    _enabled = on;
    notifyListeners();
    if (!on) unawaited(_stop());
    _saved = _saved.then((_) => _persist(on));
    await _saved;
  }

  Future<void> _persist(bool on) async {
    try {
      final dir = await DeviceServices.filesDir();
      final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      if (on) {
        if (await file.exists()) await file.delete();
      } else {
        await file.writeAsString('1');
      }
    } catch (_) {}
  }

  /// Says [text] if cues are on. Never throws: a cue is a convenience, not part of the session.
  void say(String text) {
    if (!_enabled || text.trim().isEmpty) return;
    unawaited(_speak(text).catchError((_) {}));
  }

  void silence() => unawaited(_stop().catchError((_) {}));
}
