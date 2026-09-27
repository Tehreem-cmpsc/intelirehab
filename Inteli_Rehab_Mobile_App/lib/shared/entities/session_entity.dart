import '../enums/fatigue_level.dart';
import '../enums/movement_quality.dart';

class SessionEntity {
  final String id;
  final String patientId;
  final String exerciseId;
  final int completedReps;
  final int targetReps;
  final double maxRom;
  final double targetRom;
  final double averageScore;
  final MovementQuality overallQuality;
  final FatigueLevel maxFatigue;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isSynced;

  const SessionEntity({
    required this.id,
    required this.patientId,
    required this.exerciseId,
    required this.completedReps,
    required this.targetReps,
    required this.maxRom,
    required this.targetRom,
    required this.averageScore,
    this.overallQuality = MovementQuality.good,
    this.maxFatigue = FatigueLevel.none,
    required this.startTime,
    this.endTime,
    this.isSynced = false,
  });
}
