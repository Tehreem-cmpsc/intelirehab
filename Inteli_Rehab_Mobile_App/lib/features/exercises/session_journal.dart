import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

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
///    so a retry after a partial failure never duplicates rows;
///  * failed: sessions the server permanently refuses (or that can't be
///    read). They're set aside - never retried forever, never blocking the
///    sessions behind them, and never deleted - so nothing is silently lost.
///
/// The journal is patient data, so it is never overwritten after a read it
/// couldn't complete: a transient I/O error propagates to the caller instead
/// of looking like "empty", and a corrupt file is renamed aside (not
/// replaced) so its contents can still be recovered.
class SessionJournal {
  static const _fileName = 'session_journal.json';

  /// Postgres/PostgREST codes meaning "this row will never be accepted":
  /// foreign-key, not-null, check, bad-text-representation, RLS denial.
  static const _permanentCodes = {'23503', '23502', '23514', '22P02', '42501'};

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

  /// Missing file -> empty. Corrupt file -> set aside, then empty. Anything
  /// else (an I/O error) propagates, so callers never write over data they
  /// failed to read.
  static Future<Map<String, dynamic>> _read() async {
    final f = await _file();
    if (!await f.exists()) return {};
    final text = await f.readAsString();
    try {
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (_) {
      try {
        await f.rename('${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      } catch (_) {}
      return {};
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

  /// Best-effort: failing to clear only means the patient is asked about an
  /// already-saved session on the next launch.
  static Future<void> clearInProgress() => _locked(() async {
        try {
          final data = await _read();
          if (data.remove('inProgress') != null) await _write(data);
        } catch (_) {}
      });

  static Future<UnfinishedSession?> readInProgress(String patientId) => _locked(() async {
        try {
          final raw = (await _read())['inProgress'];
          if (raw is! Map || raw['patientId'] != patientId) return null;
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
        try {
          final pending = ((await _read())['pending'] as List?) ?? const [];
          return pending.where((p) => (p as Map)['patientId'] == patientId).length;
        } catch (_) {
          return 0;
        }
      });

  /// Sessions set aside because they can never upload (see class doc).
  static Future<int> failedCount(String patientId) => _locked(() async {
        try {
          final failed = ((await _read())['failed'] as List?) ?? const [];
          return failed.where((p) => (p as Map)['patientId'] == patientId).length;
        } catch (_) {
          return 0;
        }
      });

  static bool _isPermanent(Object e) => e is PostgrestException && _permanentCodes.contains(e.code);

  /// Moves one queued entry from `pending` to `failed`, keeping the data.
  static Future<void> _setAside(Map<String, dynamic> entry, String reason) => _locked(() async {
        final data = await _read();
        final pending = List<Map<String, dynamic>>.from((data['pending'] as List?) ?? const []);
        final id = (entry['result'] as Map?)?['id'];
        pending.removeWhere((p) => (p['result'] as Map?)?['id'] == id);
        final failed = List<Map<String, dynamic>>.from((data['failed'] as List?) ?? const []);
        failed.add({...entry, 'reason': reason, 'failedAt': DateTime.now().toIso8601String()});
        data['pending'] = pending;
        data['failed'] = failed;
        await _write(data);
      });

  /// A session finished offline (or before the band's id could be looked up)
  /// is queued without a device id; look it up now so it isn't uploaded
  /// without one for good. Best-effort.
  static Future<String?> _lookUpDeviceId(ExercisesRepository repo, String patientId) async {
    try {
      return await repo.pairedDeviceId(patientId).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Uploads whatever is queued for [patientId]. Returns how many made it.
  /// A transient failure (offline, timeout) stops and keeps the rest for
  /// next time; a permanent one sets that session aside and carries on, so
  /// one bad entry can't block everything behind it.
  static Future<int> syncPending(String patientId, ExercisesRepository repo) async {
    final queued = await _locked(() async {
      final pending = ((await _read())['pending'] as List?) ?? const [];
      return [for (final p in pending) Map<String, dynamic>.from(p as Map)]
          .where((p) => p['patientId'] == patientId)
          .toList();
    });

    var synced = 0;
    for (final entry in queued) {
      final SessionResult result;
      try {
        result = SessionResult.fromJson(Map<String, dynamic>.from(entry['result'] as Map));
      } catch (_) {
        await _setAside(entry, 'unreadable');
        continue;
      }

      final deviceId = (entry['deviceId'] as String?) ?? await _lookUpDeviceId(repo, patientId);
      try {
        await repo
            .saveSession(patientId: patientId, deviceId: deviceId, result: result)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        if (_isPermanent(e)) {
          await _setAside(entry, 'rejected: ${e is PostgrestException ? e.code : e}');
          continue;
        }
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
