import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/dashed_ring.dart';
import '../../../core/widgets/theme_toggle.dart';

/// Teal gradient header, modelled on the portal login's hero panel
/// (primary-deep -> primary with the dashed orbit ring), carrying the
/// logo, a segmented progress bar and the step's title.
class OnboardingHeader extends StatelessWidget {
  final int stepIndex;
  final int stepCount;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  /// Icon for [onBack] — an arrow normally, a close icon once going back
  /// would undo a saved step.
  final IconData backIcon;
  final String backTooltip;

  const OnboardingHeader({
    super.key,
    required this.stepIndex,
    required this.stepCount,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.backIcon = Icons.arrow_back,
    this.backTooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.headerStart, c.headerEnd],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(right: -70, top: -60, child: DashedRing(size: 220, spin: true)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 50,
                    child: Row(
                      children: [
                        if (onBack != null)
                          IconButton(
                            onPressed: onBack,
                            icon: Icon(backIcon, color: Colors.white),
                            tooltip: backTooltip,
                          )
                        else
                          const SizedBox(width: 8),
                        const AppLogo(size: 30, onDark: true, showTagline: false),
                        const Spacer(),
                        Text(
                          '${stepIndex + 1}/$stepCount',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const ThemeToggle(onDark: true),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        _SegmentedProgress(index: stepIndex, count: stepCount),
                        const SizedBox(height: 18),
                        Text(
                          eyebrow,
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  final int index;
  final int count;
  const _SegmentedProgress({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                decoration: BoxDecoration(
                  color: i < index
                      ? Colors.white
                      : i == index
                          ? c.accent
                          : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
