import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository_fake.dart';
import '../../domain/repositories/auth_repository.dart';
import '../validators/auth_validators.dart';
import '../widgets/login_auth_error_banner.dart';
import '../widgets/login_preview_notice.dart';
import '../widgets/login_submit_button.dart';

/// Patient registration screen built for Inteli-Rehab.
///
/// Key characteristics:
/// - Light mode only, matching the calm healthcare aesthetic of Login and Patient Stories.
/// - Single open form column on the soft page background (#F5F8F7).
/// - No brand logo on registration (logo is restricted to Login only).
/// - Modular presentational sub-widgets adhering to Frontend Engineering Standards.
/// - Considerate touched-field validation and actionable error guidance.
/// - Memory-safe lifecycle: immediate password clearing, visibility reset, controller disposal.
/// - Safe navigation return to Login with honest preview confirmation.
class RegisterScreen extends StatefulWidget {
  final AuthRepository? repository;
  final bool isPreview;

  const RegisterScreen({
    super.key,
    this.repository,
    this.isPreview = AppConfig.isFrontendPreview,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final AuthRepository _authRepository;
  final _formKey = GlobalKey<FormState>();

  final _regIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _regIdFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _submitting = false;
  bool _obscurePassword = true;
  bool _regIdTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authRepository =
        widget.repository ??
        (sl.isRegistered<AuthRepository>()
            ? sl<AuthRepository>()
            : AuthRepositoryFake());

    _regIdController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);

    _regIdFocusNode.addListener(_onRegIdFocusChanged);
    _emailFocusNode.addListener(_onEmailFocusChanged);
    _passwordFocusNode.addListener(_onPasswordFocusChanged);
  }

  void _onFieldChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
  }

  void _onRegIdFocusChanged() {
    if (!_regIdFocusNode.hasFocus) {
      if (_regIdController.text.isNotEmpty || _regIdTouched) {
        setState(() => _regIdTouched = true);
      }
    }
  }

  void _onEmailFocusChanged() {
    if (!_emailFocusNode.hasFocus) {
      if (_emailController.text.isNotEmpty || _emailTouched) {
        setState(() => _emailTouched = true);
      }
    }
  }

  void _onPasswordFocusChanged() {
    if (!_passwordFocusNode.hasFocus) {
      if (_passwordController.text.isNotEmpty || _passwordTouched) {
        setState(() => _passwordTouched = true);
      }
    }
  }

  @override
  void dispose() {
    _regIdController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);

    _regIdFocusNode.removeListener(_onRegIdFocusChanged);
    _emailFocusNode.removeListener(_onEmailFocusChanged);
    _passwordFocusNode.removeListener(_onPasswordFocusChanged);

    _regIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    _regIdFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid => AuthValidators.isRegisterFormValid(
    regId: _regIdController.text,
    email: _emailController.text,
    password: _passwordController.text,
  );

  String? get _regIdError =>
      AuthValidators.validateClinicRegId(_regIdController.text);

  String? get _emailError =>
      AuthValidators.validateEmail(_emailController.text);

  String? get _passwordError =>
      AuthValidators.validatePassword(_passwordController.text);

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_submitting) return;

    setState(() {
      _regIdTouched = true;
      _emailTouched = true;
      _passwordTouched = true;
    });

    if (!_isFormValid) return;

    final regId = _regIdController.text.trim();
    final normalizedEmail = AuthValidators.normalizeEmail(
      _emailController.text,
    );
    final rawPassword = _passwordController.text;

    // Immediately wipe password from UI controller memory
    _passwordController.clear();

    setState(() {
      _submitting = true;
      _obscurePassword = true;
      _passwordTouched = false;
      _errorMessage = null;
    });

    try {
      await _authRepository.registerWithRegId(
        email: normalizedEmail,
        password: rawPassword,
        regId: regId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'We couldn’t complete registration. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _passwordController.clear();
          _obscurePassword = true;
          _passwordTouched = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const Key('register_back_button'),
            icon: const Icon(Icons.arrow_back_rounded),
            color: colors.heading,
            tooltip: 'Back to sign in',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // B. One main heading: "Patient registration"
                        Text(
                          'Patient registration',
                          style: GoogleFonts.sora(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: colors.heading,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // C. Supporting text: "Use the registration ID provided by your clinic."
                        Text(
                          'Use the registration ID provided by your clinic.',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // D. Short preview notice, when preview mode is active
                        if (widget.isPreview) ...[
                          const LoginPreviewNotice(
                            text:
                                'Frontend preview — use sample details. No account will be created.',
                          ),
                          const SizedBox(height: 24),
                        ],

                        // E. Clinic registration ID field group
                        _buildRegIdField(colors),
                        const SizedBox(height: 20),

                        // F. Email address field group
                        _buildEmailField(colors),
                        const SizedBox(height: 20),

                        // G. Create password field group
                        _buildPasswordField(colors),

                        // H. Form-level error when needed
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 18),
                          LoginAuthErrorBanner(
                            bannerKey: const Key('register_error_banner'),
                            message: _errorMessage!,
                          ),
                        ],
                        const SizedBox(height: 24),

                        // I. Primary "Register" button
                        LoginSubmitButton(
                          buttonKey: const Key('register_submit_button'),
                          isSubmitting: _submitting,
                          isValid: _isFormValid,
                          onSubmit: _submit,
                          label: 'Register',
                          submittingLabel: 'Registering…',
                        ),
                        const SizedBox(height: 12),

                        // J. Secondary "Already registered? Sign in" action
                        _buildBackToLoginAction(colors),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegIdField(AppThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Clinic registration ID',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.bodyText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('register_reg_id_field'),
          controller: _regIdController,
          focusNode: _regIdFocusNode,
          enabled: !_submitting,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          style: GoogleFonts.manrope(fontSize: 16, color: colors.bodyText),
          decoration: InputDecoration(
            hintText: 'REG-101',
            helperText: 'Use the registration ID given to you by your clinic.',
            helperMaxLines: 2,
            errorText: _regIdTouched ? _regIdError : null,
          ),
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_emailFocusNode);
          },
        ),
      ],
    );
  }

  Widget _buildEmailField(AppThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Email address',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.bodyText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('register_email_field'),
          controller: _emailController,
          focusNode: _emailFocusNode,
          enabled: !_submitting,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          enableSuggestions: false,
          style: GoogleFonts.manrope(fontSize: 16, color: colors.bodyText),
          decoration: InputDecoration(
            hintText: 'you@example.com',
            errorText: _emailTouched ? _emailError : null,
          ),
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_passwordFocusNode);
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(AppThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Create password',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.bodyText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('register_password_field'),
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          enabled: !_submitting,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          autocorrect: false,
          enableSuggestions: false,
          style: GoogleFonts.manrope(fontSize: 16, color: colors.bodyText),
          decoration: InputDecoration(
            hintText: '••••••••',
            helperText: 'Use at least 8 characters.',
            errorText: (_passwordTouched && _errorMessage == null)
                ? _passwordError
                : null,
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
                  : () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onFieldSubmitted: (_) {
            if (_isFormValid && !_submitting) {
              _submit();
            }
          },
        ),
      ],
    );
  }

  Widget _buildBackToLoginAction(AppThemeColors colors) {
    return Center(
      child: TextButton(
        key: const Key('register_back_to_login_button'),
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: RichText(
          text: TextSpan(
            text: 'Already registered? ',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: colors.secondaryText,
            ),
            children: [
              TextSpan(
                text: 'Sign in',
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
