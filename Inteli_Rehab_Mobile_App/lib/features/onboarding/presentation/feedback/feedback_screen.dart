import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../main.dart' show AuthGate;

/// Native Flutter feedback wall. Uses pure widget animations without any video
/// asset to keep the animation lightweight, 100% offline-ready, and smooth on all devices.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with TickerProviderStateMixin {
  late final AnimationController _wallController;
  late final AnimationController _logoController;
  Timer? _loginTimer;
  bool _navigating = false;

  static const List<String> _feedback = <String>[
    'My exercises follow\nthe plan my therapist set.',
    'I can see how my arm\nmoves on the screen.',
    'The voice prompts help me\nfocus on each movement.',
    'Seeing my repetitions counted\nhelps me stay on track.',
    'The rest reminders help me\npause and check how I feel.',
    'I can look back at my\nrange-of-motion progress.',
    'My therapist can review\nmy sessions between visits.',
    'This makes my home routine\neasier to follow.',
  ];

  @override
  void initState() {
    super.initState();
    _wallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8200),
    )..forward();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _wallController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _logoController.forward();
        _loginTimer = Timer(const Duration(milliseconds: 3600), _openLogin);
      }
    });
  }

  void _openLogin() {
    if (!mounted || _navigating) return;
    _navigating = true;
    _loginTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loginTimer?.cancel();
    _wallController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundWhite,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _wallController,
                builder: (context, child) => _FeedbackWall(
                  progress: _wallController.value,
                  feedback: _feedback,
                ),
              ),
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => _LogoReveal(
                  progress: CurvedAnimation(
                    parent: _logoController,
                    curve: Curves.easeOutCubic,
                  ).value,
                ),
              ),
              Positioned(
                top: 8,
                right: 16,
                child: TextButton(
                  onPressed: _openLogin,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Text(
                  'PATIENT FEEDBACK · INTELI-REHAB',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1,
                    color: AppTheme.sensorGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackWall extends StatelessWidget {
  final double progress;
  final List<String> feedback;

  const _FeedbackWall({
    required this.progress,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final zoom = 2.25 - (1.25 * Curves.easeInOut.transform(progress));
    final spread = Curves.easeInOut.transform(((progress - 0.55) / 0.45).clamp(0.0, 1.0).toDouble());
    const positions = <Offset>[
      Offset(-0.32, -0.28),
      Offset(0.25, -0.20),
      Offset(-0.30, 0.02),
      Offset(0.24, 0.10),
      Offset(-0.28, 0.30),
      Offset(0.28, 0.36),
      Offset(-0.55, 0.12),
      Offset(0.52, -0.02),
    ];

    return ClipRect(
      child: Stack(
        children: [
          for (var i = 0; i < feedback.length; i++)
            Positioned.fill(
              child: Align(
                alignment: Alignment(
                  positions[i].dx * (1.0 + spread),
                  positions[i].dy * (1.0 + spread),
                ),
                child: Transform.scale(
                  scale: zoom * (i.isEven ? 1.0 : 0.94),
                  child: Opacity(
                    opacity: (1.0 - (0.28 * spread)).clamp(0.0, 1.0).toDouble(),
                    child: Text(
                      feedback[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.sensorGrey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogoReveal extends StatelessWidget {
  final double progress;

  const _LogoReveal({required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == 0) return const SizedBox.shrink();
    return Center(
      child: Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.82 + (0.18 * progress),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/full_logo.png',
                width: 210,
                height: 210,
                semanticLabel: 'Inteli-Rehab logo',
              ),
              const SizedBox(height: 18),
              const Text(
                'Inteli-Rehab',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryTealDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Guided recovery, connected care.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.sensorGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
