import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../exercises_repository.dart';

/// The physiotherapist's current warning (patients.warning) and whether the patient has said they saw it.
class WarningState {
  final String message;
  final bool seen;
  const WarningState(this.message, {this.seen = false});
}

/// Shows the physiotherapist's current warning wherever the patient is about to act on it: on Home and
/// before starting an exercise, not only on the Progress tab. "Got it" tells the physiotherapist it was
/// seen; the warning itself stays until the patient's next session clears it. Shows nothing when there is
/// no warning, or while loading, or if it cannot be loaded - a warning is never worth an error message.
class WarningBanner extends StatefulWidget {
  final String patientId;

  /// Tests (and anything else) can supply their own source.
  final Future<WarningState?> Function()? load;
  final Future<void> Function()? acknowledge;

  const WarningBanner({super.key, required this.patientId, this.load, this.acknowledge});

  @override
  State<WarningBanner> createState() => _WarningBannerState();
}

class _WarningBannerState extends State<WarningBanner> {
  WarningState? _warning;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final w = await (widget.load ?? () => ExercisesRepository().currentWarning(widget.patientId))();
      if (mounted) setState(() => _warning = w);
    } catch (_) {
      // No banner. The Progress tab still shows the warning.
    }
  }

  Future<void> _gotIt() async {
    final w = _warning;
    if (w == null) return;
    setState(() => _warning = WarningState(w.message, seen: true));
    try {
      await (widget.acknowledge ?? () => ExercisesRepository().acknowledgeWarning())();
    } catch (_) {
      // The patient has still read it; the physiotherapist just won't see the receipt.
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _warning;
    if (w == null) return const SizedBox.shrink();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        color: c.alertTint,
        semanticLabel: 'Message from your physiotherapist: ${w.message}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.campaign_outlined, color: c.alert, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Message from your physiotherapist',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.ink)),
                      const SizedBox(height: 4),
                      Text(w.message, style: TextStyle(fontSize: 14, height: 1.4, color: c.ink)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: w.seen
                  ? Text('Your physiotherapist can see you read this', style: TextStyle(fontSize: 12, color: c.muted))
                  : FilledButton.tonal(onPressed: _gotIt, child: const Text('Got it')),
            ),
          ],
        ),
      ),
    );
  }
}
