import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../exercises_models.dart';

/// The three movement-safety tiers (Rule 18), used only for real-time
/// movement/fatigue feedback — never for muscle activation, which is its
/// own visually distinct system (MuscleActivationBar). Shape carries the
/// meaning as much as color (Rule 9): check / triangle / octagon.
/// Largest, most visually prominent element on screen while active
/// (Rule 8 — correction/safety outranks everything else).
class SafetyBanner extends StatelessWidget {
  final SafetyTier tier;
  final VoidCallback onAcknowledgeUnsafe;

  const SafetyBanner({super.key, required this.tier, required this.onAcknowledgeUnsafe});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, bg, fg, title, text) = switch (tier) {
      SafetyTier.normal => (Icons.check_circle, c.successTint, c.success, 'Good form', 'Keep going'),
      SafetyTier.needsCorrection => (
          Icons.change_history,
          c.accent.withValues(alpha: 0.16),
          c.accent,
          'Needs correction',
          'Lower your arm',
        ),
      SafetyTier.unsafe => (
          Icons.report,
          c.alertTint,
          c.alert,
          'Potentially unsafe movement',
          'Pause and reset your form before continuing',
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, size: 40, color: fg),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 4),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.9))),
          if (tier == SafetyTier.unsafe) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAcknowledgeUnsafe,
              style: FilledButton.styleFrom(backgroundColor: fg, foregroundColor: c.onPrimary),
              child: const Text('I understand, continue'),
            ),
          ],
        ],
      ),
    );
  }
}
