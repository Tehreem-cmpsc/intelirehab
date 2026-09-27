import '../models/physiotherapist_model.dart';

abstract class PhysiotherapistRemoteDataSource {
  Future<List<PhysiotherapistModel>> getPhysiotherapists(String clinicId);
}

class PhysiotherapistRemoteDataSourceImpl implements PhysiotherapistRemoteDataSource {
  @override
  Future<List<PhysiotherapistModel>> getPhysiotherapists(String clinicId) async {
    return [];
  }
}
