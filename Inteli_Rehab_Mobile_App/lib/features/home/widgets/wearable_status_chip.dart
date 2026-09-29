import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../wearable_connection_controller.dart';

/// The always-visible status chip (Rule 4) plus, when connected, a
/// battery reading next to it — icon + percentage, never a bare color
/// (Rule 9), and only worded more urgently below the documented
/// thresholds (Rule 17 — reserve visual weight for what matters).
/// [onDark] is the variant for the teal Home header. Announced as one
/// phrase to screen readers (Rule 28).
class WearableStatusChip extends StatelessWidget {
  final WearableConnState state;
  final int? batteryPercent;
  final bool onDark;

  const WearableStatusChip({super.key, required this.state, this.batteryPercent, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (dot, label, color) = switch (state) {
      WearableConnState.connected => ('●', 'Connected', onDark ? const Color(0xFF8BF0C0) : c.success),
      WearableConnState.calibrating => ('◐', 'Calibrating', c.accent),
      WearableConnState.disconnected => ('○', 'Disconnected', onDark ? Colors.white : c.muted),
      WearableConnState.searching => ('◌', 'Searching', c.accent),
    };
    final showBattery = state == WearableConnState.connected && batteryPercent != null;
    final spoken = [
      'Wearable $label',
      if (showBattery)
        'battery $batteryPercent percent${_note(batteryPercent!) == null ? '' : ', ${_note(batteryPercent!)}'}',
    ].join(', ');

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withValues(alpha: 0.14) : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dot, style: TextStyle(fontSize: 12, color: color, height: 1)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: onDark ? Colors.white : color)),
              ],
            ),
          ),
          if (showBattery) ...[
            const SizedBox(width: 8),
            _Battery(percent: batteryPercent!, onDark: onDark),
          ],
        ],
      ),
    );
  }

  static String? _note(int percent) => percent < 10 ? 'Charge now' : (percent < 20 ? 'Charge soon' : null);
}

class _Battery extends StatelessWidget {
  final int percent;
  final bool onDark;
  const _Battery({required this.percent, required this.onDark});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final urgent = percent < 10;
    final note = WearableStatusChip._note(percent);
    final icon = urgent ? Icons.battery_alert : (percent < 20 ? Icons.battery_2_bar : Icons.battery_full);
    final text = Text(
      note == null ? '$percent%' : '$percent% — $note',
      style: TextStyle(
        fontSize: 12,
        fontWeight: urgent ? FontWeight.w800 : FontWeight.w600,
        color: urgent ? c.alert : (onDark ? Colors.white : c.muted),
      ),
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: urgent ? c.alert : (onDark ? Colors.white : c.muted)),
        const SizedBox(width: 3),
        text,
      ],
    );
    // "Charge now" is the one battery state allowed a stronger visual
    // weight: its own pill, so it reads even on the teal header.
    if (!urgent) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: onDark ? Colors.white : c.alertTint, borderRadius: BorderRadius.circular(20)),
      child: row,
    );
  }
}
