import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

/// Secondary action row allowing new patients to navigate to registration.
class LoginRegisterAction extends StatelessWidget {
  final bool enabled;
  final VoidCallback onRegister;

  const LoginRegisterAction({
    super.key,
    required this.enabled,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Center(
      child: TextButton(
        key: const Key('login_register_button'),
        onPressed: enabled ? onRegister : null,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: RichText(
          text: TextSpan(
            text: 'New patient? ',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: colors.secondaryText,
            ),
            children: [
              TextSpan(
                text: 'Register',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.primaryButton,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
