import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import 'bluetooth_rationale.dart';
import 'wearable_connection_controller.dart';

/// The Inteli Band is compulsory: with no live BLE link, this covers the
/// whole app and the only ways forward are connecting or signing out.
/// Shown above (not instead of) the tab pages, so their state survives a
/// transient drop and is right where the patient left it on reconnect.
class BandRequiredGate extends StatelessWidget {
  final WearableConnectionController connection;
  final VoidCallback onSignOut;

  const BandRequiredGate({super.key, required this.connection, required this.onSignOut});

  Future<void> _connect(BuildContext context) async {
    // The Bluetooth permission step only exists on phones; elsewhere go
    // straight to reconnect(), which reports that the platform is unsupported.
    final onPhone = Platform.isAndroid || Platform.isIOS;
    if (onPhone && !await BluetoothRationale.ensure(context)) return;
    if (Platform.isAndroid && await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      try {
        await FlutterBluePlus.turnOn(); // system "turn on Bluetooth?" dialog
      } catch (_) {
        // Declined — reconnect() below reports "Turn on Bluetooth".
      }
    }
    await connection.reconnect();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        if (connection.isConnected) return const SizedBox.shrink();

        final c = context.colors;
        final busy =
            connection.state == WearableConnState.searching || connection.state == WearableConnState.calibrating;
        final permissionIssue = connection.lastError?.contains('permission') ?? false;

        return PopScope(
          canPop: false,
          child: Material(
            color: c.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(),
                    IconBadge(busy ? Icons.bluetooth_searching : Icons.bluetooth_disabled_rounded,
                        color: busy ? c.primary : c.alert, size: 84),
                    const SizedBox(height: 24),
                    Text(
                      busy ? (connection.stage ?? 'Connecting to your band…') : 'Connect your Inteli Band',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      connection.lastError ??
                          'Your band is required to use Inteli Rehab. Switch it on, keep it within arm’s reach '
                              'and make sure Bluetooth is on.',
                      textAlign: TextAlign.center,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, color: c.muted, height: 1.45),
                    ),
                    const SizedBox(height: 28),
                    if (busy) ...[
                      const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: connection.cancelSearch, child: const Text('Cancel')),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _connect(context),
                          icon: const Icon(Icons.bluetooth, size: 20),
                          label: Text(connection.lastError == null ? 'Connect my band' : 'Try again'),
                        ),
                      ),
                      if (permissionIssue) ...[
                        const SizedBox(height: 8),
                        const TextButton(onPressed: openAppSettings, child: Text('Open app settings')),
                      ],
                    ],
                    const Spacer(),
                    TextButton(onPressed: onSignOut, child: const Text('Sign out')),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
