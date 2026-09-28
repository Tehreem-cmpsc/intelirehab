import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/auth_repository.dart';
import '../validators/auth_validators.dart';

/// Patient registration screen built for frontend preview.
/// Conforms to Frontend Engineering Standards (modular sub-widgets, zero business logic,
/// zero magic colors, centralized semantic palette, and strict WCAG AA contrast).
class RegisterScreen extends StatefulWidget {
  final AuthRepository? repository;

  const RegisterScreen({super.key, this.repository});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final AuthRepository _authRepository;
  final _formKey = GlobalKey<FormState>();
  final _regIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.repository ?? sl<AuthRepository>();
    _regIdController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _regIdController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _regIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isFormValid => AuthValidators.isRegisterFormValid(
    regId: _regIdController.text,
    email: _emailController.text,
    password: _passwordController.text,
  );

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate() || _submitting) return;

    final regId = _regIdController.text.trim();
    final normalizedEmail = AuthValidators.normalizeEmail(
      _emailController.text,
    );
    final rawPassword = _passwordController.text;

    // Immediately wipe password from UI controller memory
    _passwordController.clear();

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.registerWithRegId(
        email: normalizedEmail,
        password: rawPassword,
        regId: regId,
      );

      if (mounted) {
        final colors = AppTheme.colors(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: colors.infoSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.border),
            ),
            content: Text(
              'Frontend Preview: Input accepted for $regId. Honest note: No real account was saved to the database.',
              style: GoogleFonts.manrope(
                color: colors.infoText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Registration could not be completed. Please check your Clinic Registration ID.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: Text(
          'Patient Registration',
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colors.heading,
          ),
        ),
        leading: IconButton(
          tooltip: 'Back to Sign In',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.heading),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _RegisterPreviewBanner(),
                    const SizedBox(height: 16),
                    const _InstructionsCard(),
                    const SizedBox(height: 20),
                    _buildRegisterFormCard(colors),
                    const SizedBox(height: 20),
                    _BackToLoginButton(
                      submitting: _submitting,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterFormCard(AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.heading.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clinic Registration ID
          TextFormField(
            key: const Key('register_reg_id_field'),
            controller: _regIdController,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.bodyText,
            ),
            decoration: const InputDecoration(
              labelText: 'Clinic Registration ID',
              hintText: 'e.g. REG-101 or AMC-004',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: AuthValidators.validateClinicRegId,
          ),
          const SizedBox(height: 16),

          // Email Field
          TextFormField(
            key: const Key('register_email_field'),
            controller: _emailController,
            enabled: !_submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: GoogleFonts.manrope(fontSize: 16, color: colors.bodyText),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'patient@clinic.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: AuthValidators.validateEmail,
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            key: const Key('register_password_field'),
            controller: _passwordController,
            enabled: !_submitting,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            style: GoogleFonts.manrope(fontSize: 16, color: colors.bodyText),
            decoration: InputDecoration(
              labelText: 'Create Password',
              hintText: 'Min. 8 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: colors.secondaryText,
                  size: 22,
                ),
                onPressed: _submitting
                    ? null
                    : () =>
                          setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: AuthValidators.validatePassword,
          ),

          // Error Display
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _RegisterErrorBanner(
              key: const Key('register_error_banner'),
              message: _errorMessage!,
            ),
          ],
          const SizedBox(height: 24),

          // Register Submit Button (Solid Teal / Mint with WCAG AA Contrast)
          ElevatedButton(
            key: const Key('register_submit_button'),
            onPressed: (!_submitting && _isFormValid) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: colors.primaryButtonText,
                    ),
                  )
                : Text(
                    'Register',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.primaryButtonText,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modular Sub-Widgets (Presentational / Single Responsibility)
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterPreviewBanner extends StatelessWidget {
  const _RegisterPreviewBanner();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.previewBannerBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.previewBannerBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 22,
            color: colors.previewBannerText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Frontend Preview Mode — Registration accepts inputs for review. No database records are created.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.previewBannerText,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.infoSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: colors.infoText,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinic-Issued Registration ID',
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colors.infoText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the unique Registration ID provided by your clinic doctor (e.g. REG-101, AMC-004) to link your prescribed rehab program.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: colors.infoText.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterErrorBanner extends StatelessWidget {
  final String message;

  const _RegisterErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.errorText, size: 18),
          const SizedBox(width: 8),
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
    );
  }
}

class _BackToLoginButton extends StatelessWidget {
  final bool submitting;
  final VoidCallback onPressed;

  const _BackToLoginButton({required this.submitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return Center(
      child: TextButton.icon(
        key: const Key('register_back_to_login_button'),
        onPressed: submitting ? null : onPressed,
        icon: Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: colors.primaryButton,
        ),
        label: Text(
          'Already registered? Return to Sign In',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: colors.primaryButton,
          ),
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
