import '../entities/clinic_entity.dart';

abstract class ClinicRepository {
  Future<List<ClinicEntity>> getClinics();
}
