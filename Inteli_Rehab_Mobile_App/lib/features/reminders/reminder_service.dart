import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// The patient's daily exercise reminder: whether it is on and at what time.
class ReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  /// Days between reminders, from the plan's frequency (see [planIntervalDays]).
  final int intervalDays;

  const ReminderSettings({this.enabled = false, this.hour = 18, this.minute = 0, this.intervalDays = 1});

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute, int? intervalDays}) => ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        intervalDays: intervalDays ?? this.intervalDays,
      );

  /// "6:00 PM" - for the settings row.
  String label() {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }
}

/// How often a plan asks the patient to exercise, in days between sessions. The plan's frequency is free
/// text chosen from a short list in the portal ("Daily", "Every other day", "3× per week", "Weekly").
/// An unknown or missing one counts as daily: a reminder that is too frequent is better than a missed one.
int intervalDaysFor(String? frequency) {
  final f = (frequency ?? '').toLowerCase();
  if (f.contains('every other')) return 2;
  if (f.contains('3') && f.contains('week')) return 2; // three a week: about every second day
  if (f.contains('week') && !f.contains('per')) return 7; // "Weekly"
  if (f.contains('twice') && f.contains('week')) return 3;
  return 1;
}

/// The most demanding exercise on the plan decides how often to remind.
int planIntervalDays(Iterable<String?> frequencies) {
  var days = 0;
  for (final f in frequencies) {
    final d = intervalDaysFor(f);
    if (days == 0 || d < days) days = d;
  }
  return days == 0 ? 1 : days;
}

/// What the reminder needs from the phone. A seam so screens can be tested without a device.
abstract class ReminderBackend {
  Future<ReminderSettings> read();

  /// Asks for permission to show notifications if needed. False when the patient says no.
  Future<bool> ensurePermission();

  Future<void> enable(ReminderSettings settings);
  Future<void> disable();
  Future<void> setIntervalDays(int days);
  Future<void> markSessionDone();
}

/// The Android implementation: the alarm and the notification are in Reminders.kt, reached through the
/// same channel as the other device helpers. On platforms without it everything quietly does nothing.
class PlatformReminderBackend implements ReminderBackend {
  static const _channel = MethodChannel('inteli_rehab/device');

  @override
  Future<ReminderSettings> read() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('getReminder');
      if (m == null) return const ReminderSettings();
      return ReminderSettings(
        enabled: m['enabled'] == true,
        hour: (m['hour'] as num?)?.toInt() ?? 18,
        minute: (m['minute'] as num?)?.toInt() ?? 0,
        intervalDays: (m['intervalDays'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {
      return const ReminderSettings();
    }
  }

  @override
  Future<bool> ensurePermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited || status.isProvisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> enable(ReminderSettings settings) async {
    await _channel.invokeMethod<void>('setReminder', {
      'hour': settings.hour,
      'minute': settings.minute,
      'intervalDays': settings.intervalDays,
    });
  }

  @override
  Future<void> disable() => _channel.invokeMethod<void>('cancelReminder');

  @override
  Future<void> setIntervalDays(int days) => _channel.invokeMethod<void>('setReminderInterval', days);

  @override
  Future<void> markSessionDone() => _channel.invokeMethod<void>('markSessionDone');
}

/// Entry point for the app. Every call here is best effort: a reminder is a convenience, so a failure
/// is never shown to the patient or allowed to interrupt what they are doing.
class ReminderService {
  ReminderService._();

  static ReminderBackend backend = PlatformReminderBackend();

  /// Tests: swap in a fake.
  static void useBackend(ReminderBackend b) => backend = b;

  /// A session was finished (or one from today was found): today's reminder is not needed.
  static void sessionDone() => unawaited(backend.markSessionDone().catchError((_) {}));

  /// Keeps the reminder in step with the plan's frequency (weekly plan: not every day).
  static void syncPlanFrequencies(Iterable<String?> frequencies) =>
      unawaited(backend.setIntervalDays(planIntervalDays(frequencies)).catchError((_) {}));
}
