import 'package:flutter/material.dart';

import '../../core/models/patient_profile.dart';
import '../auth/auth_service.dart';

/// Shown once a patient has claimed their registration ID but their
/// physio hasn't approved them yet — mirrors the physio-side "Pending"
/// state that already exists in the web portal (usePhysiotherapists.js).
class PendingApprovalScreen extends StatelessWidget {
  final PatientProfile profile;

  const PendingApprovalScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top, size: 48),
                const SizedBox(height: 16),
                Text('Welcome, ${profile.name}', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  "Your registration is complete. Your physiotherapist needs to review "
                  "and approve your file before you can start tracking sessions.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => AuthService().signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
