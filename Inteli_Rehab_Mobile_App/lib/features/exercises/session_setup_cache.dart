import 'dart:convert';
import 'dart:io';

import '../../core/platform/device_services.dart';
import 'exercises_models.dart';

/// Remembers, on the phone, what [SessionSetup] last said for a patient: their own reference range and the
/// red limits their physiotherapist set. Starting an exercise offline would otherwise fall back to the
/// built-in defaults, silently ignoring a stricter limit the physiotherapist chose for this patient.
///
/// Every part is kept separately: what the server could not be asked this time is taken from the last
/// time it could, and anything newly read replaces the old. A failure to read or write the file is never
/// an error - the session just starts with whatever it has.
class SessionSetupCache {
  SessionSetupCache._();

  static String _fileName(String patientId) => 'session_setup_${patientId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.json';

  static Future<File> _file(String patientId) async {
    final dir = await DeviceServices.filesDir();
    return File('${dir.path}${Platform.pathSeparator}${_fileName(patientId)}');
  }

  /// What was last saved for this patient, or null if nothing (or it cannot be read).
  static Future<SessionSetup?> read(String patientId) async {
    try {
      final file = await _file(patientId);
      if (!await file.exists()) return null;
      return SessionSetup.fromJson(Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map));
    } catch (_) {
      return null;
    }
  }

  /// Combines what was just read with what was remembered, saves the result, and returns it.
  /// [fresh] parts that could not be read ([SessionSetup.referenceKnown] / [SessionSetup.safetyKnown] false)
  /// come from the cache instead; if the cache has nothing either they stay unknown, i.e. default.
  static Future<SessionSetup> resolve(String patientId, SessionSetup fresh) async {
    final cached = await read(patientId);
    final useFreshReference = fresh.referenceKnown || !(cached?.referenceKnown ?? false);
    final useFreshSafety = fresh.safetyKnown || !(cached?.safetyKnown ?? false);
    final merged = SessionSetup(
      referenceRangeDeg: useFreshReference ? fresh.referenceRangeDeg : cached!.referenceRangeDeg,
      maxAngleDeg: useFreshSafety ? fresh.maxAngleDeg : cached!.maxAngleDeg,
      maxSpeedDegPerSec: useFreshSafety ? fresh.maxSpeedDegPerSec : cached!.maxSpeedDegPerSec,
      referenceKnown: useFreshReference ? fresh.referenceKnown : true,
      safetyKnown: useFreshSafety ? fresh.safetyKnown : true,
    );
    if (merged.referenceKnown || merged.safetyKnown) {
      try {
        await (await _file(patientId)).writeAsString(jsonEncode(merged.toJson()));
      } catch (_) {}
    }
    return merged;
  }
}
