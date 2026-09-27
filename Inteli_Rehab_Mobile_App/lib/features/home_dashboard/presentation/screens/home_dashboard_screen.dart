import 'package:flutter/material.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inteli-Rehab Dashboard'),
      ),
      body: const Center(
        child: Text('Main Home Dashboard Screen Skeleton'),
      ),
    );
  }
}
