import 'package:flutter/material.dart';

import '../../core/models/patient_profile.dart';
import '../auth/auth_service.dart';

/// Placeholder landing screen for an approved patient. The real rehab
/// session / wearable / progress features (FR-7 through FR-15) aren't
/// built yet — this just confirms the auth + approval flow works end to
/// end.
class HomeScreen extends StatelessWidget {
  final PatientProfile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
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
                const Icon(Icons.check_circle, size: 48, color: Colors.green),
                const SizedBox(height: 16),
                Text("You're approved!", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (profile.injury != null) Text('Injury on file: ${profile.injury}'),
                const SizedBox(height: 8),
                const Text('Session tracking and wearable connectivity are coming soon.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
