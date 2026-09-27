import '../../../../shared/entities/clinic_entity.dart';
import '../../domain/repositories/clinic_repository.dart';

/// Fake clinic repository — returns dummy clinic list for UI development.
/// DO NOT delete: Kashmala owns this. Tehreem edits clinic_repository_impl.dart instead.
class ClinicRepositoryFake implements ClinicRepository {
  @override
  Future<List<ClinicEntity>> getClinics() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return const [
      ClinicEntity(
        id: 'clinic-001',
        name: 'Shifa Rehabilitation Center',
        address: 'Blue Area, Islamabad',
        phone: '+92-51-111-000-001',
        email: 'info@shifa-rehab.pk',
      ),
      ClinicEntity(
        id: 'clinic-002',
        name: 'PIMS Physical Therapy Unit',
        address: 'G-8/3, Islamabad',
        phone: '+92-51-111-000-002',
        email: 'physio@pims.gov.pk',
      ),
      ClinicEntity(
        id: 'clinic-003',
        name: 'National Orthopedic & Rehab Clinic',
        address: 'F-7 Markaz, Islamabad',
        phone: '+92-51-111-000-003',
        email: 'nrc@ortho.pk',
      ),
    ];
  }
}
