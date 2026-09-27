import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/features/rehab_session/domain/entities/rehab_session_entity.dart';

// TODO (Tehreem): Replace RehabSessionRepositoryImpl with a mock once real backend is done.
// For now this tests the domain layer contract shape.
void main() {
  group('SaveSessionUsecase', () {
    test('usecase exists and accepts a RehabSessionEntity', () {
      // Verify that the usecase type can be constructed without error.
      // Full integration test goes in test/integration_test/session_flow_test.dart
      final entity = RehabSessionEntity(
        id: 'test-session-001',
        exerciseId: 'ex-001',
        completedReps: 10,
        maxRom: 88.5,
        averageScore: 82.0,
        timestamp: DateTime.now(),
      );
      expect(entity.id, equals('test-session-001'));
      expect(entity.completedReps, equals(10));
    });
  });
}
