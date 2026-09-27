import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../main.dart' show AuthGate;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _navTimer;

  // ── Reveal animation (logo assembly + text) ────────────────────────────────
  // NOTE: the Interval boundaries/curves below are untouched from the
  // original choreography — only the overall controller duration is longer,
  // which stretches every component's timing proportionally without
  // changing the order or feel of the reveal.
  late final AnimationController _splashController;
  late final Animation<double> _thinLineOpacity;
  late final Animation<double> _thinLineScale;
  late final Animation<double> _leftArcOpacity;
  late final Animation<Offset> _leftArcSlide;
  late final Animation<double> _rightArcOpacity;
  late final Animation<Offset> _rightArcSlide;
  late final Animation<double> _armOpacity;
  late final Animation<double> _armScale;
  late final Animation<double> _headOpacity;
  late final Animation<double> _headSlide;
  late final Animation<double> _splashTextOpacity;
  late final Animation<double> _splashTextScale;

  // ── Ambient loop (runs after reveal finishes) ──────────────────────────────
  late final AnimationController _ambientController; // glow pulse + float
  late final Animation<double> _glowPulse;
  late final Animation<double> _logoFloat;

  late final AnimationController _ringController; // slow rotating halo ring
  late final AnimationController _subtitleController; // second text beat
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleSlide;

  late final AnimationController _dotsController; // status dots

  bool _revealComplete = false;
  bool _navigating = false;

  // ── Exact Logo Teal Green Palette ──────────────────────────────────────────
  final Color _primaryTealDark = AppTheme.primaryTealDark; // #0F7159
  final Color _primaryTeal = AppTheme.primaryTeal; // #149B7B
  final Color _tealLight = AppTheme.tealLight; // #27BA9B
  final Color _sensorGrey = AppTheme.sensorGrey; // #37474F
  final Color _bg = AppTheme.backgroundWhite;
  final Color _softTealTint = AppTheme.tealSoftBackground; // #E8F7F4

  @override
  void initState() {
    super.initState();

    _initSplashAnimations();
    _initAmbientAnimations();
    _initSubtitleAnimation();
    _initDotsAnimation();

    _splashController.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _revealComplete = true);
      _ambientController.repeat(reverse: true);
      _ringController.repeat();
      _dotsController.repeat();
      _subtitleController.forward();
      _scheduleNavigation();
    });
  }

  void _initSplashAnimations() {
    // Was 2400ms — slowed to 3800ms so the reveal reads as deliberate and
    // premium rather than rushed. Same Intervals/curves as before.
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _thinLineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      ),
    );
    _thinLineScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
      ),
    );

    _leftArcOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.20, 0.45, curve: Curves.easeIn),
      ),
    );
    _leftArcSlide = Tween<Offset>(begin: const Offset(-50, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _splashController,
            curve: const Interval(0.20, 0.45, curve: Curves.easeOutCubic),
          ),
        );

    _rightArcOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.30, 0.55, curve: Curves.easeIn),
      ),
    );
    _rightArcSlide = Tween<Offset>(begin: const Offset(50, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _splashController,
            curve: const Interval(0.30, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _armOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.50, 0.75, curve: Curves.easeIn),
      ),
    );
    _armScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.50, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _headOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.68, 0.85, curve: Curves.easeIn),
      ),
    );
    _headSlide = Tween<double>(begin: -100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.68, 0.88, curve: Curves.bounceOut),
      ),
    );

    _splashTextOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.80, 1.0, curve: Curves.easeIn),
      ),
    );
    _splashTextScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _initAmbientAnimations() {
    // Slower breathing glow (was 2000ms) — a fast pulse read as flashy;
    // a longer cycle reads as calm and confident.
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _glowPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );

    _logoFloat = Tween<double>(begin: -7.0, end: 7.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );

    // Slow full rotation for the halo ring behind the logo — 9s per turn,
    // barely perceptible as motion, reads as a subtle premium detail.
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
  }

  void _initSubtitleAnimation() {
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _subtitleOpacity = CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeIn,
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeOutCubic));
  }

  void _initDotsAnimation() {
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  void _scheduleNavigation() {
    // Was 900ms — extended to ~2100ms so there's real time to register the
    // glow, the subtitle beat, and the status line before cutting to login.
    _navTimer = Timer(const Duration(milliseconds: 2100), _goToAuthGate);
  }

  void _goToAuthGate() {
    if (_navigating || !mounted) return;
    _navigating = true;
    _navTimer?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(fade),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _splashController.dispose();
    _ambientController.dispose();
    _ringController.dispose();
    _subtitleController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double logoSize = (screenWidth * 0.60).clamp(165.0, 240.0);

    return Scaffold(
      backgroundColor: _bg,
      body: GestureDetector(
        onTap: _revealComplete ? _goToAuthGate : null,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 2200),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 1.1,
                colors: _revealComplete
                    ? [
                        _softTealTint,
                        _softTealTint.withValues(alpha: 0.55),
                        Colors.white,
                      ]
                    : [Colors.white, Colors.white, _softTealTint],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGlowingLogo(logoSize),
                    const SizedBox(height: 40),
                    _buildBrandText(),
                    const SizedBox(height: 14),
                    _buildSubtitle(),
                  ],
                ),
                Positioned(
                  bottom: 52,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: _revealComplete ? 1.0 : 0.0,
                    child: _buildStatusFooter(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo + halo ring + ambient glow / float ─────────────────────────────────
  Widget _buildGlowingLogo(double logoSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _splashController,
        _ambientController,
        _ringController,
      ]),
      builder: (context, _) {
        final double floatOffset = _revealComplete ? _logoFloat.value : 0.0;
        final double glow = _revealComplete ? _glowPulse.value : 0.0;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Slow-rotating halo ring — a thin conic sweep, very low
              // opacity, purely a premium accent behind the logo.
              if (_revealComplete)
                Transform.rotate(
                  angle: _ringController.value * 6.28319,
                  child: Container(
                    width: logoSize * 1.5,
                    height: logoSize * 1.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          _tealLight.withValues(alpha: 0.0),
                          _tealLight.withValues(alpha: 0.18),
                          _tealLight.withValues(alpha: 0.0),
                          _tealLight.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.15, 0.30, 1.0],
                      ),
                    ),
                  ),
                ),
              // Soft radial glow, pulsing gently behind the assembled logo.
              if (glow > 0)
                Container(
                  width: logoSize * 1.3,
                  height: logoSize * 1.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _tealLight.withValues(alpha: 0.20 * glow),
                        _tealLight.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              _buildStaticLogoStack(logoSize),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticLogoStack(double logoSize) {
    final double scale = logoSize / 568.0;

    final double thinOpacity = _thinLineOpacity.value;
    final double thinScale = _thinLineScale.value;

    final double leftOpacity = _leftArcOpacity.value;
    final Offset leftSlide = _leftArcSlide.value;

    final double rightOpacity = _rightArcOpacity.value;
    final Offset rightSlide = _rightArcSlide.value;

    final double armOpacity = _armOpacity.value;
    final double armScaleFactor = _armScale.value;

    final double headOpacityVal = _headOpacity.value;
    final double headSlideVal = _headSlide.value;

    return SizedBox(
      width: logoSize,
      height: logoSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Component 1: Thin Line — light teal accent
          Positioned(
            top: 95.0 * scale,
            left: 279.0 * scale,
            width: 289.0 * scale,
            height: 454.0 * scale,
            child: Opacity(
              opacity: thinOpacity,
              child: Transform.scale(
                scale: thinScale,
                child: Image.asset(
                  'assets/images/thin_line.png',
                  fit: BoxFit.contain,
                  color: _tealLight,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),

          // Component 2: Left Arc — deep rich teal
          Positioned(
            top: 2.0 * scale,
            left: 1.0 * scale,
            width: 329.0 * scale,
            height: 562.0 * scale,
            child: Opacity(
              opacity: leftOpacity,
              child: Transform.translate(
                offset: leftSlide * scale,
                child: Image.asset(
                  'assets/images/left_hand.png',
                  fit: BoxFit.contain,
                  color: _primaryTealDark,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),

          // Component 3: Right Arc — vibrant teal body
          Positioned(
            top: 69.0 * scale,
            left: 78.0 * scale,
            width: 267.0 * scale,
            height: 267.0 * scale,
            child: Opacity(
              opacity: rightOpacity,
              child: Transform.translate(
                offset: rightSlide * scale,
                child: Image.asset(
                  'assets/images/right_hand.png',
                  fit: BoxFit.contain,
                  color: _primaryTeal,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),

          // Component 4: Arm — natural skin and wearable sensor bands
          Positioned(
            top: 128.0 * scale,
            left: 168.0 * scale,
            width: 357.0 * scale,
            height: 364.0 * scale,
            child: Opacity(
              opacity: armOpacity,
              child: Transform.scale(
                scale: armScaleFactor,
                child: Image.asset(
                  'assets/images/human_hand.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Component 5: Head — deep rich teal
          Positioned(
            top: (12.0 + headSlideVal) * scale,
            left: 103.0 * scale,
            width: 90.0 * scale,
            height: 90.0 * scale,
            child: Opacity(
              opacity: headOpacityVal,
              child: Image.asset(
                'assets/images/filled_circle.png',
                fit: BoxFit.contain,
                color: _primaryTealDark,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand wordmark ──────────────────────────────────────────────────────────
  Widget _buildBrandText() {
    return AnimatedBuilder(
      animation: _splashController,
      builder: (context, child) => Opacity(
        opacity: _splashTextOpacity.value,
        child: Transform.scale(scale: _splashTextScale.value, child: child),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              text: 'Inteli',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: _primaryTealDark,
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(
                  text: '-Rehab',
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    color: _primaryTeal,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryTealDark, _tealLight],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: _tealLight.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _tealLight.withValues(alpha: 0.25)),
            ),
            child: Text(
              'SMART WEARABLE REHABILITATION SYSTEM',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _primaryTealDark,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Secondary subtitle beat — fades in once ambient phase begins ──────────
  Widget _buildSubtitle() {
    return SlideTransition(
      position: _subtitleSlide,
      child: FadeTransition(
        opacity: _subtitleOpacity,
        child: Text(
          'Recover smarter · Move better',
          style: GoogleFonts.manrope(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: _sensorGrey.withValues(alpha: 0.65),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  // ── Status line + loading dots ─────────────────────────────────────────────
  Widget _buildStatusFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Preparing your recovery space',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _sensorGrey.withValues(alpha: 0.55),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        _buildLoadingDots(),
      ],
    );
  }

  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final double t = (_dotsController.value - (i * 0.22)) % 1.0;
            final double scale = 0.6 + 0.4 * (1 - (2 * t - 1).abs());
            final double opacity = 0.3 + 0.7 * (1 - (2 * t - 1).abs());

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale.clamp(0.6, 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_primaryTealDark, _tealLight],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}