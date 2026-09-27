import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class SessionReplayScreen extends StatefulWidget {
  final String sessionTitle;
  final String date;

  const SessionReplayScreen({
    super.key,
    this.sessionTitle = 'Elbow Flexion & Extension — Set 1',
    this.date = 'Yesterday, 4:30 PM',
  });

  @override
  State<SessionReplayScreen> createState() => _SessionReplayScreenState();
}

class _SessionReplayScreenState extends State<SessionReplayScreen> {
  bool _isPlaying = false;
  double _currentSeconds = 18.0;
  final double _totalSeconds = 120.0;
  Timer? _playbackTimer;

  // Calculated angle and emg based on scrubber position
  double get _currentAngle {
    // Wave oscillation simulating 4 reps across 120 seconds
    final phase = (_currentSeconds % 30.0) / 30.0;
    if (phase < 0.5) {
      return 10.0 + (phase * 2 * 78.0);
    } else {
      return 88.0 - ((phase - 0.5) * 2 * 78.0);
    }
  }

  int get _currentEmg {
    final a = _currentAngle;
    return (20 + (a / 88.0 * 55)).toInt();
  }

  int get _currentRepNumber {
    return (_currentSeconds ~/ 30) + 1;
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted) return;
        setState(() {
          if (_currentSeconds < _totalSeconds) {
            _currentSeconds += 0.5;
          } else {
            _currentSeconds = 0.0;
            _isPlaying = false;
            t.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  String _formatTime(double sec) {
    final m = (sec.toInt() ~/ 60).toString().padLeft(2, '0');
    final s = (sec.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.sessionTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(widget.date, style: const TextStyle(fontSize: 11, color: AppTheme.slate500)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Interactive Digital Twin Playback Area ─────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppTheme.slate200, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Angle Arc Indicator
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: (_currentAngle / 90.0).clamp(0.0, 1.0),
                              strokeWidth: 9,
                              strokeCap: StrokeCap.round,
                              backgroundColor: AppTheme.slate100,
                              color: AppTheme.primaryTeal,
                            ),
                          ),

                          // Synchronized Arm Transformation
                          Transform.rotate(
                            angle: (_currentAngle * 3.14159 / 180.0) * 0.4,
                            child: Image.asset(
                              'assets/images/human hand.png',
                              height: 130,
                              fit: BoxFit.contain,
                            ),
                          ),

                          // Angle Badge
                          Positioned(
                            bottom: 22,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.navy,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${_currentAngle.toInt()}° ROM Recorded',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Repetition $_currentRepNumber of 4 • Timestamp: ${_formatTime(_currentSeconds)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Live EMG Bio-potential Track ───────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.tealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.primaryTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recorded Muscle EMG Activation',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                            ),
                            Text(
                              '$_currentEmg% MVC',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primaryTeal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _currentEmg / 100.0,
                            minHeight: 6,
                            backgroundColor: AppTheme.slate100,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Scrubber & Playback Controls ───────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(_currentSeconds),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryTeal),
                      ),
                      Text(
                        _formatTime(_totalSeconds),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate500),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primaryTeal,
                      inactiveTrackColor: AppTheme.slate200,
                      thumbColor: AppTheme.navy,
                      overlayColor: AppTheme.primaryTeal.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _currentSeconds,
                      min: 0.0,
                      max: _totalSeconds,
                      onChanged: (val) {
                        setState(() => _currentSeconds = val);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentSeconds = (_currentSeconds - 5.0).clamp(0.0, _totalSeconds);
                          });
                        },
                        icon: const Icon(Icons.replay_5_rounded, size: 28),
                        color: AppTheme.slate600,
                      ),
                      const SizedBox(width: 14),
                      IconButton.filled(
                        onPressed: _togglePlayback,
                        icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentSeconds = (_currentSeconds + 5.0).clamp(0.0, _totalSeconds);
                          });
                        },
                        icon: const Icon(Icons.forward_5_rounded, size: 28),
                        color: AppTheme.slate600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
