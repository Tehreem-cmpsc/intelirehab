import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/services/supabase_service.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/screens/auth_session_preview_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/onboarding/presentation/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Dependency Injection (GetIt switch for fake/real repos)
  setupInjection();

  // 2. Initialize live Supabase client only when not in frontend-preview configuration
  // (Frontend-only preview uses fake repositories; Tehreem integrates real backend later).
  if (!AppConfig.isFrontendPreview) {
    try {
      await SupabaseService.initialize();
    } catch (e) {
      debugPrint('Supabase initialization skipped: $e');
    }
  }

  runApp(const InteliRehabApp());
}

class InteliRehabApp extends StatelessWidget {
  final ThemeMode themeMode;

  const InteliRehabApp({super.key, this.themeMode = ThemeMode.light});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inteli-Rehab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}

/// Dynamic routing based on authentication state from AuthRepository.
/// Monitors app lifecycle to enforce 30-minute inactivity session expiry on resume.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late final AuthRepository _authRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authRepository = sl<AuthRepository>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authRepository.checkSessionExpiry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _authRepository.authStateChanges,
      initialData: _authRepository.isAuthenticated,
      builder: (context, snapshot) {
        final isAuthenticated = snapshot.data ?? false;
        if (!isAuthenticated) {
          return const LoginScreen();
        }
        return AuthSessionPreviewScreen(repository: _authRepository);
      },
    );
  }
}
