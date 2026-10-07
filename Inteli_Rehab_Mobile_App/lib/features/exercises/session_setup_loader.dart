import 'exercises_models.dart';
import 'exercises_repository.dart';
import 'session_setup_cache.dart';

/// The patient's own range and their physiotherapist's limits, ready for a session. Waits only briefly:
/// offline or slow, the session starts with what the phone last saw for this patient (SessionSetupCache),
/// and only with the built-in defaults if it has never seen them - it does not hold the patient up.
/// [load] is where the server answer comes from; tests pass their own.
Future<SessionSetup> loadSessionSetup(String patientId, {Future<SessionSetup> Function()? load}) async {
  SessionSetup fresh;
  try {
    fresh = await (load ?? () => ExercisesRepository().loadSessionSetup(patientId)).call().timeout(
          const Duration(seconds: 4),
        );
  } catch (_) {
    fresh = SessionSetup.unreadable;
  }
  return SessionSetupCache.resolve(patientId, fresh);
}
