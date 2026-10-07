import 'package:flutter/material.dart';

import '../../core/platform/device_services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../home/bluetooth_rationale.dart';
import '../home/wearable_connection_controller.dart';
import 'active_session_screen.dart';
import 'exercises_models.dart';
import 'session_setup_loader.dart';
import 'widgets/exercise_media.dart';
import 'widgets/warning_banner.dart';

/// STATE 2 — pre-start. [Start Exercise] is pinned in the thumb zone
/// (Rule 21) and disabled with a reason beneath when the wearable isn't
/// connected (the SRS alt-flow), with a visible Reconnect (Rule 33) — the
/// reason shows before the patient taps, not sprung on them after.
class ExerciseDetailScreen extends StatelessWidget {
  final AssignedExercise exercise;
  final String patientId;
  final WearableConnectionController connection;
  final VoidCallback onViewProgress;
  final String armSide;

  /// Where the patient's setup comes from; tests pass their own.
  final Future<SessionSetup> Function()? loadSetup;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    required this.patientId,
    required this.connection,
    required this.onViewProgress,
    this.armSide = 'left',
    this.loadSetup,
  });

  /// Phone battery at or below this is "critically low" for Rule 31. The
  /// wearable's own battery is a separate warning, never merged with this.
  static const _lowPhoneBattery = 15;

  Future<void> _start(BuildContext context) async {
    final battery = await DeviceServices.phoneBattery();
    if (!context.mounted) return;
    if (battery != null && battery <= _lowPhoneBattery) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.battery_alert, color: context.colors.alert, size: 32),
          title: const Text('Your phone battery is low'),
          content: Text('It\'s at $battery%. Charge before starting a longer session.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Start anyway')),
            FilledButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Charge first')),
          ],
        ),
      );
      if (go != true || !context.mounted) return;
    }
    final setup = await _loadSetup();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ActiveSessionScreen(
        exercise: exercise,
        patientId: patientId,
        connection: connection,
        onViewProgress: onViewProgress,
        armSide: armSide,
        setup: setup,
      ),
    ));
  }

  Future<SessionSetup> _loadSetup() => loadSessionSetup(patientId, load: loadSetup);

  Future<void> _reconnect(BuildContext context) async {
    if (!await BluetoothRationale.ensure(context)) return;
    await connection.reconnect();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final instructions = exercise.description?.trim().isNotEmpty == true
        ? exercise.description!.trim()
        : 'Move slowly and within a comfortable range. Stop if you feel sharp pain.';

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // A warning from the physiotherapist is the last thing to read before starting.
          WarningBanner(patientId: patientId),
          Row(
            children: [
              const IconBadge(Icons.accessibility_new, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PillTag(exercise.difficulty, icon: Icons.signal_cellular_alt),
                        if (exercise.target != null)
                          PillTag(exercise.target!, color: c.accent, icon: Icons.my_location),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ExerciseMedia(mediaUrl: exercise.mediaUrl, mediaType: exercise.mediaType, name: exercise.name),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: StatTile(icon: Icons.layers_outlined, value: '${exercise.sets}', label: 'Sets')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(icon: Icons.repeat, value: '${exercise.repsTarget}', label: 'Reps per set')),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.straighten,
                  value: exercise.romTarget == null ? '—' : '${exercise.romTarget}%',
                  label: 'ROM target',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionLabel('How to do it'),
          AppCard(child: Text(instructions, style: TextStyle(fontSize: 14.5, color: c.ink, height: 1.55))),
          const SizedBox(height: 14),
          AppCard(
            color: c.primaryTint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: c.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Keep your phone somewhere you can see it. The app will tell you if your form needs correcting.',
                    style: TextStyle(fontSize: 13, color: c.ink, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: connection,
        builder: (context, _) {
          final connected = connection.isConnected;
          final busy =
              connection.state == WearableConnState.searching || connection.state == WearableConnState.calibrating;
          return BottomActionBar(
            children: [
              if (!connected)
                Row(
                  children: [
                    Icon(Icons.bluetooth_disabled_rounded, size: 18, color: c.alert),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        busy ? 'Connecting to your wearable…' : 'Reconnect your wearable to continue.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.alert),
                      ),
                    ),
                    TextButton(onPressed: busy ? null : () => _reconnect(context), child: const Text('Reconnect')),
                  ],
                ),
              FilledButton.icon(
                onPressed: connected ? () => _start(context) : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Exercise'),
              ),
            ],
          );
        },
      ),
    );
  }
}
