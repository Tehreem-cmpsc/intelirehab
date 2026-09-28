import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository_fake.dart';
import '../../domain/repositories/auth_repository.dart';
import '../validators/auth_validators.dart';
import '../widgets/login_auth_error_banner.dart';
import '../widgets/login_brand_header.dart';
import '../widgets/login_preview_notice.dart';
import '../widgets/login_register_action.dart';
import '../widgets/login_submit_button.dart';
import 'auth_session_preview_screen.dart';
import 'register_screen.dart';

/// Patient login screen built for Inteli-Rehab.
/// 
/// Key characteristics:
/// - Light mode only, matching the calm healthcare aesthetic of Patient Stories.
/// - Single open form column on the soft page background (#F5F8F7).
/// - Modular presentational sub-widgets adhering to Frontend Engineering Standards.
/// - Error prevention with touched-field validation and actionable error guidance.
/// - Memory-safe lifecycle: immediate password clearing, visibility reset, controller disposal.
/// - Canonical session-aware destination routing.
class LoginScreen extends StatefulWidget {
  final AuthRepository? repository;
  final bool isPreview;

  const LoginScreen({
    super.key,
    this.repository,
    this.isPreview = AppConfig.isFrontendPreview,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository _authRepository;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _submitting = false;
  bool _navigatingToRegister = false;
  bool _obscurePassword = true;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.repository ??
        (sl.isRegistered<AuthRepository>()
            ? sl<AuthRepository>()
            : AuthRepositoryFake());

    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
    _emailFocusNode.addListener(_onEmailFocusChanged);
    _passwordFocusNode.addListener(_onPasswordFocusChanged);
  }

  void _onEmailChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else if (_emailTouched) {
      setState(() {});
    } else {
      setState(() {});
    }
  }

  void _onPasswordChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else if (_passwordTouched) {
      setState(() {});
    } else {
      setState(() {});
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
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _emailFocusNode.removeListener(_onEmailFocusChanged);
    _passwordFocusNode.removeListener(_onPasswordFocusChanged);

    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool get _isFormValid => AuthValidators.isLoginFormValid(
        email: _emailController.text,
        password: _passwordController.text,
      );

  String? get _emailError => AuthValidators.validateEmail(_emailController.text);

  String? get _passwordError =>
      AuthValidators.validateLoginPassword(_passwordController.text);

  void _openRegister() {
    if (_navigatingToRegister || _submitting) return;

    setState(() {
      _navigatingToRegister = true;
      _passwordController.clear();
      _obscurePassword = true;
      _passwordTouched = false;
      _errorMessage = null;
    });

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(repository: _authRepository),
      ),
    )
        .then((_) {
      if (mounted) {
        setState(() {
          _navigatingToRegister = false;
          _passwordController.clear();
          _obscurePassword = true;
          _passwordTouched = false;
        });
      }
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_submitting) return;

    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
    });

    if (!_isFormValid) return;

    final normalizedEmail =
        AuthValidators.normalizeEmail(_emailController.text);
    final rawPassword = _passwordController.text;

    // Immediately clear password controller from memory on submission
    _passwordController.clear();

    setState(() {
      _submitting = true;
      _obscurePassword = true;
      _passwordTouched = false;
      _errorMessage = null;
    });

    try {
      await _authRepository.signIn(
        email: normalizedEmail,
        password: rawPassword,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                AuthSessionPreviewScreen(repository: _authRepository),
          ),
          (route) => false,
        );
      }
    } on InvalidCredentialsException catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Incorrect email or password.';
        });
      }
    } on AuthNetworkException catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to sign in right now. Please try again.';
        });
      }
    } on AuthReleaseModeException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to sign in right now. Please try again.';
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
    final canPop = Navigator.canPop(context);

    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        appBar: canPop
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  key: const Key('login_back_button'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: colors.heading,
                  tooltip: 'Back to patient stories',
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // B. Modest brand row
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: LoginBrandHeader(),
                        ),
                        const SizedBox(height: 28),

                        // C. Heading: "Welcome back"
                        Text(
                          'Welcome back',
                          style: GoogleFonts.sora(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: colors.heading,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // D. Supporting text
                        Text(
                          'Sign in to continue your rehabilitation.',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                            color: colors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // E. Restrained preview notice
                        if (widget.isPreview) ...[
                          const LoginPreviewNotice(),
                          const SizedBox(height: 24),
                        ],

                        // F. Email field group
                        _buildEmailField(colors),
                        const SizedBox(height: 18),

                        // G. Password field group
                        _buildPasswordField(colors),

                        // H. Inline authentication error
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 18),
                          LoginAuthErrorBanner(message: _errorMessage!),
                        ],
                        const SizedBox(height: 24),

                        // I. Primary Sign in button
                        LoginSubmitButton(
                          isSubmitting: _submitting,
                          isValid: _isFormValid,
                          onSubmit: _submit,
                        ),
                        const SizedBox(height: 12),

                        // J. Secondary Register action
                        LoginRegisterAction(
                          enabled: !_submitting && !_navigatingToRegister,
                          onRegister: _openRegister,
                        ),
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
          key: const Key('login_email_field'),
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
          'Password',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.bodyText,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('login_password_field'),
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          enabled: !_submitting,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          autocorrect: false,
          enableSuggestions: false,
          style: GoogleFonts.manrope(fontSize: 16, color: colors.bodyText),
          decoration: InputDecoration(
            hintText: '••••••••',
            // Suppress field error when global auth error is active to prevent contradictory messaging
            errorText:
                (_passwordTouched && _errorMessage == null) ? _passwordError : null,
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
}
