import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Port of the portal's ThemeToggle.jsx: a 38px rounded square showing a
/// sun in dark mode and a moon in light mode. [onDark] swaps to a
/// translucent-white style for the teal header gradients.
/// Renders nothing if there's no [ThemeScope] above it.
class ThemeToggle extends StatelessWidget {
  final bool onDark;

  const ThemeToggle({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = isDark ? 'Switch to light mode' : 'Switch to dark mode';

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: onDark ? Colors.white.withValues(alpha: 0.10) : c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: onDark ? Colors.white.withValues(alpha: 0.18) : c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => controller.toggle(Theme.of(context).brightness),
            child: SizedBox.square(
              dimension: 38,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) => RotationTransition(
                  turns: Tween(begin: 0.75, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  key: ValueKey(isDark),
                  size: 18,
                  color: onDark ? Colors.white : c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
