import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/models/patient_profile.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_service.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/onboarding_repository.dart';
import 'features/onboarding/waiting_for_physio_screen.dart';
import 'features/onboarding/welcome_screen.dart';

class InteliRehabApp extends StatefulWidget {
  const InteliRehabApp({super.key});

  @override
  State<InteliRehabApp> createState() => _InteliRehabAppState();
}

class _InteliRehabAppState extends State<InteliRehabApp> {
  final _themeController = ThemeController();

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Above MaterialApp so every route (onboarding steps, waiting screen,
    // login) shares the one theme choice.
    return ThemeScope(
      controller: _themeController,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _themeController,
        builder: (context, mode, _) => MaterialApp(
          title: 'Inteli Rehab',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Root of the navigation. Re-resolves whenever the signed-in user changes:
///
///   no session                         -> WelcomeScreen
///   signed in, no patients row yet     -> finish registration from the
///                                         answers saved at sign-up (email
///                                         confirmation case), then continue
///   no clinic chosen yet               -> OnboardingFlow, resumed at the clinic step
///   clinic chosen, not approved        -> WaitingForPhysioScreen
///   approved                           -> HomeScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  final _repo = OnboardingRepository();
  StreamSubscription<AuthState>? _subscription;
  String? _uid;
  Future<Widget>? _view;

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentSession?.user.id;
    _view = _resolve();
    // Only a change of user matters — token refreshes keep the same uid.
    _subscription = _auth.onAuthStateChange.listen((state) {
      final uid = state.session?.user.id;
      if (uid != _uid && mounted) {
        setState(() {
          _uid = uid;
          _view = _resolve();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _retry() => setState(() => _view = _resolve());

  Future<Widget> _resolve() async {
    if (_uid == null) return const WelcomeScreen();

    var row = await _auth.fetchMyPatientRow();
    if (row == null && await _repo.completeRegistrationFromMetadata() != null) {
      row = await _auth.fetchMyPatientRow();
    }
    if (row == null) return const _NoPatientRecord();

    if (row['approved'] == true) return HomeScreen(profile: PatientProfile.fromMap(row));

    final data = await _repo.hydrate(row);
    if (row['clinic_id'] == null) {
      return OnboardingFlow(initialData: data, initialStep: OnboardingFlow.firstPostAccountStep);
    }
    return WaitingForPhysioScreen(data: data);
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const WelcomeScreen();
    return FutureBuilder<Widget>(
      future: _view,
      builder: (context, snap) {
        if (snap.hasError) return _LoadError(error: snap.error!, onRetry: _retry);
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        // Keyed on the future, so a re-resolve remounts the screen fresh.
        return KeyedSubtree(key: ObjectKey(_view), child: snap.data!);
      },
    );
  }
}

class _NoPatientRecord extends StatelessWidget {
  const _NoPatientRecord();

  @override
  Widget build(BuildContext context) {
    return const _GateMessage(
      icon: Icons.person_search_outlined,
      title: "We couldn't find your patient record",
      text: 'Your login exists but registration never finished. Contact your clinic, or sign out and '
          'create your account again with a different email.',
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _GateMessage(
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load your account",
      text: error is OnboardingException
          ? (error as OnboardingException).message
          : 'Check your connection and try again.',
      onRetry: onRetry,
    );
  }
}

class _GateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onRetry;

  const _GateMessage({required this.icon, required this.title, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 48, color: c.primary),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              if (onRetry != null) ...[
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
                const SizedBox(height: 10),
              ],
              OutlinedButton(onPressed: () => AuthService().signOut(), child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
