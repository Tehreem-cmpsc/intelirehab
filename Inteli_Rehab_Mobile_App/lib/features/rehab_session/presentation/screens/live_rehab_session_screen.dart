import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../session_summary/presentation/screens/session_summary_screen.dart';

class LiveRehabSessionScreen extends StatefulWidget {
  final String exerciseName;
  final int targetReps;
  final int targetSets;
  final double targetRom;

  const LiveRehabSessionScreen({
    super.key,
    this.exerciseName = 'Elbow Flexion & Extension',
    this.targetReps = 10,
    this.targetSets = 3,
    this.targetRom = 90.0,
  });

  @override
  State<LiveRehabSessionScreen> createState() => _LiveRehabSessionScreenState();
}

class _LiveRehabSessionScreenState extends State<LiveRehabSessionScreen>
    with SingleTickerProviderStateMixin {
  int _currentSet = 1;
  int _completedReps = 0;
  double _currentAngle = 12.0; // live simulated joint angle
  double _peakRomSession = 12.0;
  int _emgActivation = 34; // % MVC
  String _aiFeedback = 'Ready! Begin bending your elbow upward smoothly.';
  bool _isPaused = false;
  int _elapsedSeconds = 0;
  Timer? _sessionTimer;
  Timer? _repSimTimer;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _repSimTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String get _formattedTime {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Simulates a complete biometric repetition with sensor curve & rep detection
  void _simulateRepetition() {
    if (_isPaused) return;
    _repSimTimer?.cancel();

    int tick = 0;
    _repSimTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) return;
      tick++;

      setState(() {
        if (tick <= 25) {
          // Ascending flexion phase (0° -> 90°)
          _currentAngle = 10.0 + (tick * 3.3);
          _emgActivation = (30 + (tick * 1.8)).clamp(30, 85).toInt();
          _aiFeedback = 'Good upward drive! Keep elbow steady.';
        } else if (tick <= 32) {
          // Peak isometric hold
          _currentAngle = widget.targetRom;
          if (_currentAngle > _peakRomSession) _peakRomSession = _currentAngle;
          _emgActivation = 72;
          _aiFeedback = 'Target ${widget.targetRom.toInt()}° ROM reached! Hold for 1s.';
        } else if (tick <= 55) {
          // Controlled extension descent
          _currentAngle = widget.targetRom - ((tick - 32) * 3.4);
          _emgActivation = (70 - ((tick - 32) * 1.8)).clamp(15, 70).toInt();
          _aiFeedback = 'Controlled descent — great eccentric control.';
        } else {
          // Rep completed
          _currentAngle = 12.0;
          _emgActivation = 22;
          _completedReps++;
          t.cancel();

          if (_completedReps >= widget.targetReps) {
            if (_currentSet < widget.targetSets) {
              _currentSet++;
              _completedReps = 0;
              _aiFeedback = 'Set completed! Take a 30s rest before Set $_currentSet.';
            } else {
              _aiFeedback = 'All sets complete! Excellent clinical adherence.';
              _finishSession();
            }
          } else {
            _aiFeedback = 'Rep $_completedReps logged! Prepare for next rep.';
          }
        }
      });
    });
  }

  void _finishSession() {
    _sessionTimer?.cancel();
    _repSimTimer?.cancel();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(
          exerciseName: widget.exerciseName,
          totalReps: (_currentSet - 1) * widget.targetReps + _completedReps,
          totalSets: widget.targetSets,
          peakRom: _peakRomSession > widget.targetRom ? widget.targetRom : _peakRomSession,
          targetRom: widget.targetRom,
          durationSeconds: _elapsedSeconds > 0 ? _elapsedSeconds : 145,
          accuracyScore: 94,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double romProgress = (_currentAngle / widget.targetRom).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.exerciseName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(
              'Set $_currentSet of ${widget.targetSets} • $_formattedTime',
              style: const TextStyle(fontSize: 12, color: AppTheme.slate500, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _finishSession,
            child: const Text('Finish', style: TextStyle(color: AppTheme.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Stats Bar (Rep Counter & Fatigue Indicator) ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  // Reps Counter
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppTheme.tealLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.repeat_rounded, color: AppTheme.primaryTeal, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_completedReps / ${widget.targetReps}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.slate800),
                              ),
                              const Text('Reps Completed', style: TextStyle(fontSize: 10.5, color: AppTheme.slate500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // EMG Activation Bar Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('EMG Activation', style: TextStyle(fontSize: 10.5, color: AppTheme.slate500)),
                              Text(
                                '$_emgActivation%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _emgActivation > 75 ? AppTheme.red : AppTheme.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _emgActivation / 100.0,
                              minHeight: 8,
                              backgroundColor: AppTheme.slate100,
                              color: _emgActivation > 75
                                  ? AppTheme.red
                                  : _emgActivation > 50
                                      ? AppTheme.amber
                                      : AppTheme.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Interactive Digital Twin & ROM Gauge Center Stage ──────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Digital Twin Limb Display
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppTheme.slate200, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Circular Arc Meter
                          SizedBox(
                            width: 210,
                            height: 210,
                            child: CircularProgressIndicator(
                              value: romProgress,
                              strokeWidth: 10,
                              strokeCap: StrokeCap.round,
                              backgroundColor: AppTheme.slate100,
                              color: romProgress >= 0.95 ? AppTheme.green : AppTheme.primaryTeal,
                            ),
                          ),

                          // Anatomical Arm Graphic
                          Transform.rotate(
                            angle: (_currentAngle * 3.14159 / 180.0) * 0.4,
                            child: Image.asset(
                              'assets/images/human_hand.png',
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                          ),

                          // Angle Overlay Pill
                          Positioned(
                            bottom: 24,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.navy,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_currentAngle.toInt()}° / ${widget.targetRom.toInt()}°',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      romProgress >= 0.95 ? 'TARGET REACHED! 🎯' : 'KEEP LIFTING SMOOTHLY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: romProgress >= 0.95 ? AppTheme.green : AppTheme.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Real-Time AI Form Feedback Bubble ──────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryTeal.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.tealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _aiFeedback,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom Session Controls ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  // Pause / Play
                  IconButton.filled(
                    onPressed: () => setState(() => _isPaused = !_isPaused),
                    icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.slate200,
                      foregroundColor: AppTheme.slate800,
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Simulate Repetition Trigger
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryTeal, AppTheme.navyMid],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _simulateRepetition,
                        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                        label: const Text(
                          'Perform / Simulate Rep',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
