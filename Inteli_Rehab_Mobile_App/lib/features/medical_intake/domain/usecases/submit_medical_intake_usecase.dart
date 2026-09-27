import '../entities/medical_intake_entity.dart';
import '../repositories/medical_intake_repository.dart';

class SubmitMedicalIntakeUsecase {
  final MedicalIntakeRepository repository;
  const SubmitMedicalIntakeUsecase(this.repository);

  Future<void> call(MedicalIntakeEntity intake) {
    return repository.submitIntake(intake);
  }
}
