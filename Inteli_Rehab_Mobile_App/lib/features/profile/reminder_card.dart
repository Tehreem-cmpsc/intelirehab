import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../reminders/reminder_service.dart';

/// Settings: a daily reminder to exercise, at a time the patient chooses. Off until they turn it on, and
/// turning it on asks the phone for permission to show notifications first. If they say no it stays off
/// and says why, rather than looking on while nothing can reach them.
class ReminderCard extends StatefulWidget {
  /// Tests pass a fake; the app uses the phone.
  final ReminderBackend? backend;
  const ReminderCard({super.key, this.backend});

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  late final ReminderBackend _backend = widget.backend ?? ReminderService.backend;
  ReminderSettings _settings = const ReminderSettings();
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _backend.read().then((s) {
      if (!mounted) return;
      setState(() {
        _settings = s;
        _loaded = true;
      });
    });
  }

  void _say(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(bool on) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (on) {
        if (!await _backend.ensurePermission()) {
          _say('Notifications are off for this app. Turn them on in your phone settings to get reminders.');
          return;
        }
        final next = _settings.copyWith(enabled: true);
        await _backend.enable(next);
        if (mounted) setState(() => _settings = next);
        _say('Reminder set for ${next.label()}.');
      } else {
        await _backend.disable();
        if (mounted) setState(() => _settings = _settings.copyWith(enabled: false));
      }
    } catch (_) {
      _say("Couldn't change the reminder. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.hour, minute: _settings.minute),
      helpText: 'Remind me at',
    );
    if (picked == null || !mounted) return;
    final next = _settings.copyWith(hour: picked.hour, minute: picked.minute);
    setState(() => _settings = next);
    try {
      if (next.enabled) await _backend.enable(next);
    } catch (_) {
      _say("Couldn't change the reminder time. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            value: _settings.enabled,
            onChanged: _loaded && !_busy ? _toggle : null,
            secondary: Icon(Icons.notifications_active_outlined, color: c.primary),
            title: Text('Remind me to exercise',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.ink)),
            subtitle: Text(
              'A daily nudge, only on days you are due and have not already exercised.',
              style: TextStyle(fontSize: 12.5, color: c.muted),
            ),
          ),
          if (_settings.enabled) ...[
            Divider(height: 1, indent: 56, color: c.border),
            ListTile(
              leading: Icon(Icons.schedule, color: c.primary),
              title: Text('Time', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.ink)),
              trailing: Text(_settings.label(), style: TextStyle(fontSize: 14, color: c.muted)),
              onTap: _pickTime,
            ),
          ],
        ],
      ),
    );
  }
}
