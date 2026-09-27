import '../entities/clinic_entity.dart';
import '../repositories/clinic_repository.dart';

class GetClinicsUsecase {
  final ClinicRepository repository;
  const GetClinicsUsecase(this.repository);

  Future<List<ClinicEntity>> call() {
    return repository.getClinics();
  }
}
