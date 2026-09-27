import '../../domain/entities/rehab_session_entity.dart';
import '../../domain/repositories/rehab_session_repository.dart';
import '../datasources/rehab_session_remote_data_source.dart';
import '../models/rehab_session_model.dart';

class RehabSessionRepositoryImpl implements RehabSessionRepository {
  final RehabSessionRemoteDataSource remoteDataSource;

  const RehabSessionRepositoryImpl(this.remoteDataSource);

  @override
  Future<void> startSession(String exerciseId) async {}

  @override
  Future<void> saveSession(RehabSessionEntity session) {
    final model = RehabSessionModel(
      id: session.id,
      exerciseId: session.exerciseId,
      completedReps: session.completedReps,
      maxRom: session.maxRom,
      averageScore: session.averageScore,
      timestamp: session.timestamp,
    );
    return remoteDataSource.saveSession(model);
  }
}
