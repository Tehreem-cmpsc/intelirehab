import '../models/medical_intake_model.dart';

abstract class MedicalIntakeRemoteDataSource {
  Future<void> submitIntake(MedicalIntakeModel model);
}

class MedicalIntakeRemoteDataSourceImpl implements MedicalIntakeRemoteDataSource {
  @override
  Future<void> submitIntake(MedicalIntakeModel model) async {}
}
