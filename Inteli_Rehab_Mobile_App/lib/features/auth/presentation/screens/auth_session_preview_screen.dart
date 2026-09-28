import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/auth_repository.dart';
import 'login_screen.dart';

/// Canonical session-aware destination screen for the frontend preview.
///
/// Enforces all security and session lifecycle requirements:
/// - Actual user interaction refreshes the 30-minute inactivity deadline.
/// - 30 minutes without activity automatically expires the session while the app is open.
/// - App resume re-verifies session expiry.
/// - Any user interaction after expiry cannot revive the stale session.
/// - Sign-out and session expiry clear preview identity and return to Login.
/// - System Back navigation cannot reveal the authenticated screen once signed out or expired.
/// - Timers, stream subscriptions, and lifecycle observers are cleanly disposed.
class AuthSessionPreviewScreen extends StatefulWidget {
  final AuthRepository? repository;
  final Duration? inactivityDuration;

  const AuthSessionPreviewScreen({
    super.key,
    this.repository,
    this.inactivityDuration,
  });

  @override
  State<AuthSessionPreviewScreen> createState() =>
      _AuthSessionPreviewScreenState();
}

class _AuthSessionPreviewScreenState extends State<AuthSessionPreviewScreen>
    with WidgetsBindingObserver {
  late final AuthRepository _authRepository;
  StreamSubscription<bool>? _authSubscription;
  Timer? _expiryCheckTimer;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authRepository = widget.repository ?? sl<AuthRepository>();

    // Initial session verification
    _authRepository.checkSessionExpiry();
    if (!_authRepository.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _returnToLogin();
      });
      return;
    }

    // Subscribe to auth state transitions
    _authSubscription = _authRepository.authStateChanges.listen((
      isAuthenticated,
    ) {
      if (!isAuthenticated && mounted && !_isExiting) {
        _returnToLogin();
      }
    });

    // Set up inactivity timer if configured
    if (widget.inactivityDuration != null) {
      _resetExpiryTimer();
    }
  }

  void _resetExpiryTimer() {
    _expiryCheckTimer?.cancel();
    if (widget.inactivityDuration != null) {
      _expiryCheckTimer = Timer(widget.inactivityDuration!, () {
        _checkExpiry();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryCheckTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkExpiry();
    }
  }

  void _checkExpiry() {
    if (_isExiting) return;
    _authRepository.checkSessionExpiry();
    if (!_authRepository.isAuthenticated) {
      _returnToLogin();
    }
  }

  /// Handles incoming pointer/tap events.
  ///
  /// Critical HCI/Security Rule:
  /// Check expiry FIRST before recording activity so an interaction after expiry
  /// cannot revive a stale session.
  void _onUserInteraction() {
    if (_isExiting) return;
    _authRepository.checkSessionExpiry();
    if (!_authRepository.isAuthenticated) {
      _returnToLogin();
      return;
    }
    _authRepository.recordActivity();
    _resetExpiryTimer();
  }

  Future<void> _signOut() async {
    if (_isExiting) return;
    _isExiting = true;
    await _authRepository.signOut();
    if (mounted) {
      _returnToLogin();
    }
  }

  void _returnToLogin() {
    if (!mounted) return;
    _isExiting = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(repository: _authRepository),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final userEmail = _authRepository.currentUserEmail ?? 'patient@clinic.com';

    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isExiting) {
          _signOut();
        }
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _onUserInteraction(),
        child: Scaffold(
          backgroundColor: colors.pageBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    semanticLabel: 'Inteli-Rehab logo',
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Inteli-Rehab',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.heading,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.infoSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Frontend Preview Session Active',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.infoText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Heading
                      Text(
                        'Sign-in preview complete',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: colors.heading,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // User Identity
                      Text(
                        'Signed in as $userEmail',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colors.bodyText,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Information Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: colors.primaryButton,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Next Steps & Integration',
                                    style: GoogleFonts.sora(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colors.heading,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You have successfully verified the frontend sign-in flow. Tehreem will integrate the production dashboard, Supabase backend authentication, and clinical data models.',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                height: 1.5,
                                color: colors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.infoSurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                    color: colors.infoText,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Session expires automatically after 30 minutes of inactivity.',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: colors.infoText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sign Out Button
                      ElevatedButton(
                        key: const Key('preview_sign_out_button'),
                        onPressed: _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primaryButton,
                          foregroundColor: colors.primaryButtonText,
                          minimumSize: const Size.fromHeight(56),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Sign out',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.primaryButtonText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
