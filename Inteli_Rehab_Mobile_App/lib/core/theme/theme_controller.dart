import 'package:flutter/material.dart';

/// One app-wide light/dark choice, like the portal's single `darkMode`
/// state in App.jsx. It sits above MaterialApp, so every screen —
/// welcome, each onboarding step, the waiting screen — follows it.
///
/// Held in memory only: it lasts for the whole session but resets to the
/// system setting on a cold start. (Persisting it needs a storage plugin.)
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.mode = ThemeMode.system]);

  /// Flips relative to what's on screen now, so the first tap from
  /// "system" always visibly changes the theme.
  void toggle(Brightness current) {
    value = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required super.child})
      : super(notifier: controller);

  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
