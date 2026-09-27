import '../entities/patient_feedback_entity.dart';

abstract class PatientFeedbackRepository {
  Future<List<PatientFeedbackEntity>> getFeaturedFeedback();
}
