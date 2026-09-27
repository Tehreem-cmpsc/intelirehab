import '../entities/medical_intake_entity.dart';

abstract class MedicalIntakeRepository {
  Future<void> submitIntake(MedicalIntakeEntity intake);
}
