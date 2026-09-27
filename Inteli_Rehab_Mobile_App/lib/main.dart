import 'package:flutter/material.dart';
import 'core/services/supabase_service.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'core/models/patient_profile.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home_dashboard/presentation/screens/home_dashboard_screen.dart';
import 'features/home_dashboard/presentation/screens/pending_approval_screen.dart';
import 'features/onboarding/presentation/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Dependency Injection (GetIt switch for fake/real repos)
  setupInjection();
  
  // 2. Initialize live Supabase client using Tehreem's backend
  await SupabaseService.initialize();

  runApp(const InteliRehabApp());
}

class InteliRehabApp extends StatelessWidget {
  const InteliRehabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inteli-Rehab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(), // ← Show splash first, then AuthGate
    );
  }
}

/// Dynamic routing based on authentication and approval state from Supabase
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder(
      stream: authService.onAuthStateChange,
      builder: (context, _) {
        final session = authService.currentSession;
        if (session == null) {
          return const LoginScreen();
        }

        return FutureBuilder<PatientProfile?>(
          future: authService.fetchMyPatientProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = snapshot.data;
            if (profile == null) {
              return Scaffold(
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, size: 48, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text(
                            "We couldn't link your patient record. Please contact your clinic.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => authService.signOut(),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return profile.approved
                ? const HomeDashboardScreen()
                : PendingApprovalScreen(profile: profile);
          },
        );
      },
    );
  }
}
