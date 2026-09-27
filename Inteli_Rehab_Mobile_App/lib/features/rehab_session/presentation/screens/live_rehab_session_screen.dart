import 'package:flutter/material.dart';
import '../widgets/digital_twin_widget.dart';
import '../widgets/rep_counter_widget.dart';
import '../widgets/ai_feedback_overlay_widget.dart';
import '../widgets/fatigue_alert_widget.dart';

class LiveRehabSessionScreen extends StatelessWidget {
  const LiveRehabSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Rehabilitation Session'),
      ),
      body: Stack(
        children: const [
          DigitalTwinWidget(),
          Positioned(
            top: 16,
            left: 16,
            child: RepCounterWidget(),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: AiFeedbackOverlayWidget(),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FatigueAlertWidget(),
          ),
        ],
      ),
    );
  }
}
