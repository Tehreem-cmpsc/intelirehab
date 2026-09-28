import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Restrained preview notice informing users of the frontend preview nature.
class LoginPreviewNotice extends StatelessWidget {
  const LoginPreviewNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.infoSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colors.infoText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Frontend preview — use sample details. No real account is accessed.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.infoText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
