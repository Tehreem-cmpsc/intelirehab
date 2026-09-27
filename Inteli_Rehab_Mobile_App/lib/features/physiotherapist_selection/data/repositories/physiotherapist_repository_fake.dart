import '../../../../shared/entities/physiotherapist_entity.dart';
import '../../domain/repositories/physiotherapist_repository.dart';

/// Fake physiotherapist repository — returns dummy therapists for UI development.
/// DO NOT delete: Kashmala owns this. Tehreem edits physiotherapist_repository_impl.dart instead.
class PhysiotherapistRepositoryFake implements PhysiotherapistRepository {
  @override
  Future<List<PhysiotherapistEntity>> getPhysiotherapists(String clinicId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const [
      PhysiotherapistEntity(
        id: 'physio-001',
        name: 'Dr. Ayesha Siddiqui',
        specialization: 'Shoulder & Rotator Cuff Rehabilitation',
        clinicId: 'clinic-001',
        email: 'ayesha@shifa-rehab.pk',
        phone: '+92-333-000-0001',
      ),
      PhysiotherapistEntity(
        id: 'physio-002',
        name: 'Dr. Omar Farooq',
        specialization: 'Stroke Rehabilitation & Neurophysio',
        clinicId: 'clinic-001',
        email: 'omar@shifa-rehab.pk',
        phone: '+92-333-000-0002',
      ),
      PhysiotherapistEntity(
        id: 'physio-003',
        name: 'Dr. Sara Khan',
        specialization: 'Post-Surgical & Orthopedic Rehab',
        clinicId: 'clinic-002',
        email: 'sara@pims.gov.pk',
        phone: '+92-333-000-0003',
      ),
    ];
  }
}
