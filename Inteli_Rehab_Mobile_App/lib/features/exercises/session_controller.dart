import 'package:flutter/foundation.dart';

import 'exercises_models.dart';

/// What the Active Session screen needs from whatever is driving a session.
/// Two implementations: [LiveSession] (the real band's sensor stream) and
/// [SessionSimulator] (a timer-driven stand-in, kept for tests and demos).
abstract interface class SessionController implements Listenable {
  /// Reps in the whole session (every set). [repsPerSet] x [setsTarget].
  int get repsTarget;
  int get romTargetPercent;

  int get setsTarget;
  int get repsPerSet;

  /// 1-based set the patient is in (the one just finished, while [isResting]).
  int get currentSet;

  /// Reps done in [currentSet].
  int get repsInCurrentSet;

  /// Between sets: paused, waiting out the rest. The screen shows the countdown and calls [endRest]
  /// when it is over or skipped, then carries on the way it does after any other pause.
  bool get isResting;
  int get restSeconds;
  void endRest();

  /// The patient pressed "This hurts": the session pauses and the moment is saved with it.
  void reportPain();

  /// Fatigue is estimated from movement speed alone (no usable muscle signal), so it is a weaker guess.
  bool get fatigueFromSpeedOnly;

  bool get isRunning;
  bool get awaitingUnsafeAck;
  bool get fatiguePauseOffered;

  int get repsCompleted;

  /// Live joint angle as % of the full range, the same unit as
  /// [romTargetPercent] (the ROM target bar compares the two).
  int get liveAngle;
  MuscleActivation get activation;
  SafetyTier get currentTier;
  FatigueLevel get fatigueLevel;

  /// What to tell the patient for the current amber/red state (null while everything is fine).
  String? get currentMessage;

  /// A soft note about the last rep, e.g. that it was slow. Never a failure.
  String? get repHint;

  /// The last rep is counted but not yet judged (a fraction of a second). The screen waits for this
  /// before finishing, so the final rep's verdict is not lost.
  bool get hasPendingCheck;
  Duration get elapsed;

  void start();
  void pause();
  void resume();
  void acknowledgeUnsafe();
  void acknowledgeFatiguePause();

  SessionResult buildResult(AssignedExercise exercise);
  void dispose();
}
