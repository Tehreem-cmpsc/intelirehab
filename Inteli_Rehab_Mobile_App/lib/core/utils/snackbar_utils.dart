import 'package:flutter/material.dart';
import 'package:inteli_rehab/core/constants/app_colors.dart';

class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_rounded,
    Color? color,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? AppColors.slate.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(milliseconds: 1800),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) => show(
    context,
    message,
    icon: Icons.check_circle_rounded,
    color: const Color(0xFF16A34A),
  );

  static void info(BuildContext context, String message) => show(
    context,
    message,
    icon: Icons.info_rounded,
    color: AppColors.tealCore,
  );

  static void warning(BuildContext context, String message) => show(
    context,
    message,
    icon: Icons.warning_rounded,
    color: Colors.amber.shade800,
  );
}
