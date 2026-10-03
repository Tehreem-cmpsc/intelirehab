import 'package:flutter/foundation.dart';

import 'exercises_models.dart';

/// What the Active Session screen needs from whatever is driving a session.
/// Two implementations: [LiveSession] (the real band's sensor stream) and
/// [SessionSimulator] (a timer-driven stand-in, kept for tests and demos).
abstract interface class SessionController implements Listenable {
  int get repsTarget;
  int get romTargetPercent;

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
  Duration get elapsed;

  void start();
  void pause();
  void resume();
  void acknowledgeUnsafe();
  void acknowledgeFatiguePause();

  SessionResult buildResult(AssignedExercise exercise);
  void dispose();
}
