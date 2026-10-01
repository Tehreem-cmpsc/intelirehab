import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/patient_profile.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../exercises/exercises_repository.dart';
import '../exercises/plan_list_screen.dart';
import '../exercises/session_journal.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
import 'band_required_gate.dart';
import 'home_screen.dart';
import 'wearable_connection_controller.dart';

/// Bottom navigation lock (Rule 2): Home | Exercises | Progress | Profile,
/// in the thumb zone (Rule 21). One [WearableConnectionController] lives
/// here, above all four tabs, so the connection state (and BR-7's gate) is
/// the same wherever it's read.
///
/// Also owns two app-level recovery behaviours:
///  * Rule 24 — system back on any tab but Home goes to Home first, rather
///    than exiting the app from a secondary tab.
///  * Rule 27 — if the OS killed the app mid-session, the next launch lands
///    here and offers to save what was recorded, instead of losing it.
class HomeShell extends StatefulWidget {
  final PatientProfile profile;
  final bool wearablePaired;
  final String? deviceSerial;

  const HomeShell({
    super.key,
    required this.profile,
    required this.wearablePaired,
    this.deviceSerial,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final _connection = WearableConnectionController(
    patientId: widget.profile.id,
    initiallyPaired: widget.wearablePaired,
    deviceSerial: widget.deviceSerial,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkUnfinishedSession();
    });
  }

  @override
  void dispose() {
    _connection.dispose();
    super.dispose();
  }

  void _goToExercises() => setState(() => _index = 1);
  void _goToProgress() => setState(() => _index = 2);

  Future<void> _checkUnfinishedSession() async {
    final unfinished = await SessionJournal.readInProgress(widget.profile.id);
    if (unfinished == null || !mounted) return;
    final r = unfinished.result;
    if (r.repsCompleted == 0) {
      await SessionJournal.clearInProgress();
      return;
    }

    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.restore, color: context.colors.primary, size: 32),
        title: const Text("Your last session wasn't saved"),
        content: Text(
          'The app closed during ${r.exercise.name}, after ${r.repsCompleted} of ${r.exercise.repsTarget} reps. '
          'Would you like to keep what you recorded?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save it')),
        ],
      ),
    );
    if (save == true) {
      await SessionJournal.enqueue(widget.profile.id, null, r);
      final synced = await SessionJournal.syncPending(widget.profile.id, ExercisesRepository());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(synced > 0 ? 'Session saved.' : "Session saved on this phone — it'll upload when you're online."),
      ));
    } else {
      await SessionJournal.clearInProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(profile: widget.profile, connection: _connection, onGoToExercises: _goToExercises),
      PlanListScreen(patientId: widget.profile.id, connection: _connection, onViewProgress: _goToProgress),
      ProgressScreen(patientId: widget.profile.id),
      ProfileScreen(
        name: widget.profile.name,
        connection: _connection,
        onSignOut: () => unawaited(AuthService().signOut()),
      ),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        // The band is compulsory: BandRequiredGate covers everything (nav
        // bar included) until a real BLE link is up.
        body: Stack(
          children: [
            IndexedStack(index: _index, children: pages),
            Positioned.fill(
              child: BandRequiredGate(
                connection: _connection,
                onSignOut: () => unawaited(AuthService().signOut()),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Exercises',
            ),
            NavigationDestination(
                icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
