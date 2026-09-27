import 'package:flutter/material.dart';
import '../../../../shared/entities/patient_entity.dart';
import '../../../auth/data/datasources/auth_remote_data_source.dart';

class PendingApprovalScreen extends StatelessWidget {
  final PatientEntity profile;

  const PendingApprovalScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Pending'),
        actions: [
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top_rounded, size: 64, color: Colors.orange.shade600),
                const SizedBox(height: 20),
                Text(
                  'Awaiting Physiotherapist Approval',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Hello ${profile.name.isNotEmpty ? profile.name : 'Patient'}, your account has been registered with your clinic. Your assigned physiotherapist will review and approve your profile on the clinic portal shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => AuthService().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
