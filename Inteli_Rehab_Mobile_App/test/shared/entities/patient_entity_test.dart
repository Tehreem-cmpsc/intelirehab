import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/shared/entities/patient_entity.dart';
import 'package:inteli_rehab/shared/enums/injury_type.dart';

void main() {
  group('PatientEntity', () {
    test('creates a lean entity with only shared fields', () {
      const patient = PatientEntity(
        id: 'p-001',
        name: 'Kashmala Zeb',
        email: 'kashmala@test.com',
        clinicId: 'c-001',
        physiotherapistId: 'ph-001',
        injuryType: InjuryType.rotatorCuffTear,
        affectedJoint: 'Right Shoulder',
        recoveryPercentage: 23.0,
        streakDays: 3,
      );

      expect(patient.id, equals('p-001'));
      expect(patient.name, equals('Kashmala Zeb'));
      expect(patient.injuryType, equals(InjuryType.rotatorCuffTear));
      expect(patient.recoveryPercentage, equals(23.0));
      expect(patient.streakDays, equals(3));

      // Confirm there's no surgeryDate, painLevel, or notes on this entity
      // (they live in MedicalIntakeEntity inside the medical_intake feature)
    });

    test('defaults are sensible for optional fields', () {
      const patient = PatientEntity(
        id: 'p-002',
        name: 'Test',
        email: 'test@test.com',
      );
      expect(patient.injuryType, equals(InjuryType.other));
      expect(patient.recoveryPercentage, equals(0.0));
      expect(patient.streakDays, equals(0));
    });
  });
}
