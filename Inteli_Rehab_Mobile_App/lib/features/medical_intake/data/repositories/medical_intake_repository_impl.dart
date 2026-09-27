import '../../domain/entities/medical_intake_entity.dart';
import '../../domain/repositories/medical_intake_repository.dart';
import '../datasources/medical_intake_remote_data_source.dart';
import '../models/medical_intake_model.dart';

class MedicalIntakeRepositoryImpl implements MedicalIntakeRepository {
  final MedicalIntakeRemoteDataSource remoteDataSource;

  const MedicalIntakeRepositoryImpl(this.remoteDataSource);

  @override
  Future<void> submitIntake(MedicalIntakeEntity intake) {
    final model = MedicalIntakeModel(
      patientId: intake.patientId,
      affectedJoint: intake.affectedJoint,
      injuryType: intake.injuryType,
      notes: intake.notes,
    );
    return remoteDataSource.submitIntake(model);
  }
}
