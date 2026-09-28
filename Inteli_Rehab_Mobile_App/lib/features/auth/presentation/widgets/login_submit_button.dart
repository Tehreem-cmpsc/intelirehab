import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Primary action button for login with loading spinner and accessibility semantics.
class LoginSubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final bool isValid;
  final VoidCallback? onSubmit;

  const LoginSubmitButton({
    super.key,
    required this.isSubmitting,
    required this.isValid,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return ElevatedButton(
      key: const Key('login_submit_button'),
      onPressed: (!isSubmitting && isValid) ? onSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryButton,
          foregroundColor: colors.primaryButtonText,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.secondaryText,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.primaryButtonText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Signing in…',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryButtonText,
                    ),
                  ),
                ],
              )
            : Text(
                'Sign in',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
  }
}
