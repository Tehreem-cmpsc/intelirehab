import 'package:flutter/material.dart';

class AiFeedbackOverlayWidget extends StatelessWidget {
  final String feedback;

  const AiFeedbackOverlayWidget({
    super.key,
    this.feedback = 'Keep elbow steady and follow guided tempo',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        feedback,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
