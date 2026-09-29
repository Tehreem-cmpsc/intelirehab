import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';

/// Rule 23: explain Bluetooth in context, right before it's needed, never
/// as a bare prompt at launch. Called before every scan/reconnect; shown
/// once per app run — the actual runtime permission request (Android 12+'s
/// BLUETOOTH_SCAN/BLUETOOTH_CONNECT) follows right after [Continue], via
/// [ArmBandBleService.requestPermissions] (called from `ensure` here so
/// every scan/reconnect site gets both the rationale and the request in
/// one call, in order).
class BluetoothRationale {
  static bool _acknowledged = false;

  static Future<bool> ensure(BuildContext context) async {
    if (!_acknowledged) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => const _RationaleSheet(),
      );
      if (ok != true) {
        if (context.mounted) showBluetoothNeeded(context);
        return false;
      }
      _acknowledged = true;
    }

    final granted = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    final ok = (granted[Permission.bluetoothScan]?.isGranted ?? true) &&
        (granted[Permission.bluetoothConnect]?.isGranted ?? true);
    if (!ok && context.mounted) showBluetoothNeeded(context);
    return ok;
  }

  /// The consequence, in plain language — never a silent failure.
  static void showBluetoothNeeded(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bluetooth access is needed to connect your wearable. Enable it in Settings.')),
    );
  }
}

class _RationaleSheet extends StatelessWidget {
  const _RationaleSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: IconBadge(Icons.bluetooth, color: c.primary, size: 60)),
            const SizedBox(height: 16),
            Text(
              'INTELI-REHAB needs Bluetooth to connect to your wearable.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink, height: 1.35),
            ),
            const SizedBox(height: 6),
            Text(
              "It's only used to talk to your Inteli Band — nothing else nearby.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
          ],
        ),
      ),
    );
  }
}
