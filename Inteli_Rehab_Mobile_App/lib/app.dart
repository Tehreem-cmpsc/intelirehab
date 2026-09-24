import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/models/patient_profile.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/pending_approval_screen.dart';

class InteliRehabApp extends StatelessWidget {
  const InteliRehabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inteli Rehab',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0D8F83), useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

/// Root of the navigation: no session -> login/register, signed in but
/// not yet approved -> pending screen, approved -> home. This is the
/// same three-state shape the web portal's usePhysiotherapists.js /
/// ApprovalsPage.jsx already use for physio onboarding.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<AuthState>(
      stream: authService.onAuthStateChange,
      builder: (context, _) {
        final session = authService.currentSession;
        if (session == null) {
          return const LoginScreen();
        }

        return FutureBuilder<PatientProfile?>(
          future: authService.fetchMyPatientProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return const Scaffold(
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "We couldn't find your patient record. If you just registered, "
                        "contact your clinic — your registration ID may not have linked "
                        "correctly.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }

            return profile.approved
                ? HomeScreen(profile: profile)
                : PendingApprovalScreen(profile: profile);
          },
        );
      },
    );
  }
}
