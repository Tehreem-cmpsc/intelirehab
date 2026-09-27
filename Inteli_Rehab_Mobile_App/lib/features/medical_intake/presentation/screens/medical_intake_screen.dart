import 'package:flutter/material.dart';

class MedicalIntakeScreen extends StatelessWidget {
  const MedicalIntakeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Intake'),
      ),
      body: const Center(
        child: Text('Medical Intake Form Screen Skeleton'),
      ),
    );
  }
}
