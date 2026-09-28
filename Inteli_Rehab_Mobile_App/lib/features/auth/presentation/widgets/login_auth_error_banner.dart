import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Inline error banner displaying safe, non-revealing authentication error feedback.
class LoginAuthErrorBanner extends StatelessWidget {
  final String message;
  final Key? bannerKey;

  const LoginAuthErrorBanner({
    super.key,
    required this.message,
    this.bannerKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        key: bannerKey ?? const Key('login_error_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.errorBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.errorBorder, width: 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colors.errorText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  color: colors.errorText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
