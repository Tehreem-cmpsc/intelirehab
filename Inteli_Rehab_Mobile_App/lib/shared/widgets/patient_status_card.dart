import 'package:flutter/material.dart';
import '../entities/patient_entity.dart';

/// Shows patient's clinic, assigned therapist name, and recovery % at a glance.
/// Used across home_dashboard, session_summary, and physiotherapist views.
class PatientStatusCard extends StatelessWidget {
  final PatientEntity patient;
  final String clinicName;
  final String therapistName;
  final VoidCallback? onTap;

  const PatientStatusCard({
    super.key,
    required this.patient,
    required this.clinicName,
    required this.therapistName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Clinic: $clinicName',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text('Therapist: $therapistName',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${patient.recoveryPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text('Recovery', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
