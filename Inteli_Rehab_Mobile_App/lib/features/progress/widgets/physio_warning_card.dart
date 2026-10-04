import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

/// The message a physiotherapist left for this patient (patients.warning, written from the portal's
/// At Risk page). Shown at the top of Progress. Plain and factual: it says who it is from and
/// repeats their words, with an icon and a title as well as colour (Rule 9).
class PhysioWarningCard extends StatelessWidget {
  final String message;
  const PhysioWarningCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      color: c.alertTint,
      semanticLabel: 'Message from your physiotherapist: $message',
      child: Row(
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
                Text(message, style: TextStyle(fontSize: 14, height: 1.4, color: c.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
