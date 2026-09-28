import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Clean brand header displaying the Inteli-Rehab logo and wordmark,
/// aligned with the content's horizontal margins.
class PatientStoriesHeader extends StatelessWidget implements PreferredSizeWidget {
  const PatientStoriesHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Image.asset(
                    'assets/images/logo.png',
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
            ),
          ),
        ),
      ),
    );
  }
}
