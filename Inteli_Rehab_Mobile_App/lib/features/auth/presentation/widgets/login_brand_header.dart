import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Compact brand row displaying the Inteli-Rehab logo and wordmark.
class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Image.asset(
            'assets/images/full_logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'Inteli-Rehab logo',
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            'Inteli-Rehab',
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.heading,
            ),
          ),
        ),
      ],
    );
  }
}
