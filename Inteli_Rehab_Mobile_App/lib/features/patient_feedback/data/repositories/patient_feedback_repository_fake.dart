import '../../domain/entities/patient_feedback_entity.dart';
import '../../domain/repositories/patient_feedback_repository.dart';

class PatientFeedbackRepositoryFake implements PatientFeedbackRepository {
  @override
  Future<List<PatientFeedbackEntity>> getFeaturedFeedback() async {
    // Simulated brief latency for loading state
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      PatientFeedbackEntity(
        id: 'demo-1',
        patientDisplayName: 'Ayesha K.',
        message: 'The repetition counter helped me stay consistent with my home exercises.',
        exerciseName: 'Elbow flexion',
        rating: 5,
        submittedAt: DateTime(2026, 9, 25),
        therapistResponse: 'Keep following your prescribed pace.',
      ),
      PatientFeedbackEntity(
        id: 'demo-2',
        patientDisplayName: 'Hassan R.',
        message: 'The movement guidance made it easier to notice when I was compensating with my shoulder.',
        exerciseName: 'Shoulder abduction',
        rating: 5,
        submittedAt: DateTime(2026, 9, 22),
        therapistResponse: 'Your form is improving.',
      ),
      PatientFeedbackEntity(
        id: 'demo-3',
        patientDisplayName: 'Sana M.',
        message: 'Seeing my range-of-motion progress gave me confidence to keep going.',
        exerciseName: 'Shoulder flexion',
        rating: 5,
        submittedAt: DateTime(2026, 9, 19),
      ),
    ];
  }
}
