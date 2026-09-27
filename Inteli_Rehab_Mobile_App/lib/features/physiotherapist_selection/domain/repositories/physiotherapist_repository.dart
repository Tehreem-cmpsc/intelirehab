import '../entities/physiotherapist_entity.dart';

abstract class PhysiotherapistRepository {
  Future<List<PhysiotherapistEntity>> getPhysiotherapists(String clinicId);
}
