class PatientFeedbackEntity {
  final String id;
  final String patientDisplayName;
  final String message;
  final String exerciseName;
  final int rating;
  final DateTime submittedAt;
  final String? therapistResponse;

  const PatientFeedbackEntity({
    required this.id,
    required this.patientDisplayName,
    required this.message,
    required this.exerciseName,
    required this.rating,
    required this.submittedAt,
    this.therapistResponse,
  });
}
