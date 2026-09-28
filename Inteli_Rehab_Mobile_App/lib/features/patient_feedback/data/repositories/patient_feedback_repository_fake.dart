import '../../domain/entities/patient_feedback_entity.dart';
import '../../domain/repositories/patient_feedback_repository.dart';

/// In-memory fake repository providing clearly labeled sample feedback for preview.
/// 
/// CLINICAL & COMPLIANCE NOTE:
/// For future production backend integration, all featured feedback items must be
/// formally reviewed and approved for public display with explicit patient consent.
/// No patient health information (PHI) or unconsented identifying data should ever
/// be exposed. Only consented public display names and approved quotes are used.
class PatientFeedbackRepositoryFake implements PatientFeedbackRepository {
  @override
  Future<List<PatientFeedbackEntity>> getFeaturedFeedback() async {
    // Simulated brief latency for loading state
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      PatientFeedbackEntity(
        id: 'demo-1',
        patientDisplayName: 'Ayesha K.',
        message:
            'I find the exercise instructions easy to follow, with everything I need in one place.',
        exerciseName: 'Patient experience',
        rating: 5,
        submittedAt: DateTime(2026, 9, 25),
      ),
      PatientFeedbackEntity(
        id: 'demo-2',
        patientDisplayName: 'Ahmed R.',
        message:
            'My session summary helps me explain how practice went when I speak with my physiotherapist.',
        exerciseName: 'Patient experience',
        rating: 5,
        submittedAt: DateTime(2026, 9, 22),
      ),
      PatientFeedbackEntity(
        id: 'demo-3',
        patientDisplayName: 'Sana M.',
        message:
            'The connection status helps me check that my wearable is ready before I begin.',
        exerciseName: 'Patient experience',
        rating: 5,
        submittedAt: DateTime(2026, 9, 19),
      ),
    ];
  }
}
