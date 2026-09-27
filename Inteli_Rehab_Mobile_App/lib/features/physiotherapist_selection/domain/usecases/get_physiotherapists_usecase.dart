import '../entities/physiotherapist_entity.dart';
import '../repositories/physiotherapist_repository.dart';

class GetPhysiotherapistsUsecase {
  final PhysiotherapistRepository repository;
  const GetPhysiotherapistsUsecase(this.repository);

  Future<List<PhysiotherapistEntity>> call(String clinicId) {
    return repository.getPhysiotherapists(clinicId);
  }
}
