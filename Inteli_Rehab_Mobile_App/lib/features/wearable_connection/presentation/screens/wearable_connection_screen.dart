import 'package:flutter/material.dart';

class WearableConnectionScreen extends StatelessWidget {
  const WearableConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable Connection'),
      ),
      body: const Center(
        child: Text('BLE Scan & Connect Screen Skeleton'),
      ),
    );
  }
}
