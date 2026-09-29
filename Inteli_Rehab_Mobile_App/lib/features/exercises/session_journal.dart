import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/platform/device_services.dart';
import 'exercises_models.dart';
import 'exercises_repository.dart';

/// A session in progress when the app last stopped, found on relaunch.
class UnfinishedSession {
  final String patientId;
  final SessionResult result;
  const UnfinishedSession({required this.patientId, required this.result});
}

/// Data & Sync Layer (SDD §3.1.5) — on-phone record of exercise sessions,
/// in app-private storage that survives backgrounding and process death:
///
///  * in-progress: rewritten after every rep, so an interruption (Rule 22)
///    or the OS killing the app (Rule 27) never loses recorded reps — on
///    relaunch the patient is asked what to do with it;
///  * pending: finished sessions that couldn't reach Supabase yet. Cloud
///    sync is offline-first (Rule 26): the patient is never blocked, and
///    [syncPending] uploads them later. Uploads are idempotent (client ids),
///    so a retry after a partial failure never duplicates rows.
class SessionJournal {
  static const _fileName = 'session_journal.json';

  // Serialises reads/writes so two quick saves can't interleave.
  static Future<void> _lock = Future.value();

  static Future<T> _locked<T>(Future<T> Function() body) {
    final completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(await body());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<File> _file() async => File('${(await DeviceServices.filesDir()).path}/$_fileName');

  static Future<Map<String, dynamic>> _read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map);
    } catch (_) {
      return {}; // A corrupt journal must never block the app.
    }
  }

  static Future<void> _write(Map<String, dynamic> data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path); // atomic replace — no half-written journal
  }

  static Future<void> saveInProgress(String patientId, SessionResult result) => _locked(() async {
        final data = await _read();
        data['inProgress'] = {'patientId': patientId, 'result': result.toJson()};
        await _write(data);
      });

  static Future<void> clearInProgress() => _locked(() async {
        final data = await _read();
        if (data.remove('inProgress') != null) await _write(data);
      });

  static Future<UnfinishedSession?> readInProgress(String patientId) => _locked(() async {
        final raw = (await _read())['inProgress'];
        if (raw is! Map || raw['patientId'] != patientId) return null;
        try {
          return UnfinishedSession(
            patientId: patientId,
            result: SessionResult.fromJson(Map<String, dynamic>.from(raw['result'] as Map)),
          );
        } catch (_) {
          return null;
        }
      });

  static Future<void> enqueue(String patientId, String? deviceId, SessionResult result) => _locked(() async {
        final data = await _read();
        final pending = List<Map<String, dynamic>>.from((data['pending'] as List?) ?? const []);
        pending.removeWhere((p) => (p['result'] as Map)['id'] == result.id);
        pending.add({'patientId': patientId, 'deviceId': deviceId, 'result': result.toJson()});
        data['pending'] = pending;
        data.remove('inProgress');
        await _write(data);
      });

  static Future<int> pendingCount(String patientId) => _locked(() async {
        final pending = ((await _read())['pending'] as List?) ?? const [];
        return pending.where((p) => (p as Map)['patientId'] == patientId).length;
      });

  /// Uploads whatever is queued for [patientId]. Returns how many made it.
  static Future<int> syncPending(String patientId, ExercisesRepository repo) async {
    final queued = await _locked(() async {
      final pending = ((await _read())['pending'] as List?) ?? const [];
      return [for (final p in pending) Map<String, dynamic>.from(p as Map)]
          .where((p) => p['patientId'] == patientId)
          .toList();
    });

    var synced = 0;
    for (final entry in queued) {
      final result = SessionResult.fromJson(Map<String, dynamic>.from(entry['result'] as Map));
      try {
        await repo
            .saveSession(patientId: patientId, deviceId: entry['deviceId'] as String?, result: result)
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        break; // Still offline — keep the rest for next time.
      }
      synced += 1;
      await _locked(() async {
        final data = await _read();
        final pending = List<Map<String, dynamic>>.from((data['pending'] as List?) ?? const []);
        pending.removeWhere((p) => (p['result'] as Map)['id'] == result.id);
        data['pending'] = pending;
        await _write(data);
      });
    }
    return synced;
  }
}
