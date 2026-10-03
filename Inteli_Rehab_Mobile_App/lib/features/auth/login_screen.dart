import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/app_logo.dart';
import '../../core/widgets/theme_toggle.dart';
import '../onboarding/onboarding_flow.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;

  const LoginScreen({super.key, this.initialEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.initialEmail);
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthGate (the root route) picks up the new session and shows the
      // right screen — resume onboarding, waiting, or home.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      final message = e.message.toLowerCase();
      setState(() => _errorMessage = message.contains('not confirmed')
          ? 'Please confirm your email first — check your inbox for the link.'
          : message.contains('invalid')
              ? 'Incorrect email or password.'
              : e.statusCode == '429' || message.contains('rate limit') || message.contains('too many')
                  ? 'Too many attempts. Wait a few minutes and try again.'
                  : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = "Couldn't reach Inteli Rehab. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _emailController.text.trim());
        return AlertDialog(
          title: const Text('Reset your password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enter your account email and we'll send you a link to choose a new password."),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline, size: 20)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Send link'),
            ),
          ],
        );
      },
    );
    if (email == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!email.contains('@')) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a valid email address.')));
      return;
    }
    try {
      await _authService.requestPasswordReset(email);
      // Same answer whether or not the address has an account.
      messenger.showSnackBar(const SnackBar(
        content: Text('If that email has an account, a reset link is on its way. Check your inbox.'),
      ));
    } on AuthException catch (e) {
      final limited = e.statusCode == '429' || e.message.toLowerCase().contains('rate limit');
      messenger.showSnackBar(SnackBar(
        content: Text(limited ? 'Too many attempts. Wait a few minutes and try again.' : "Couldn't send the email. Try again."),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't reach Inteli Rehab. Check your connection.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: const [ThemeToggle(), SizedBox(width: 16)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: AppLogo(size: 36)),
                  const SizedBox(height: 28),
                  Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue your rehab program.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline, size: 20),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _submitting ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const OnboardingFlow()),
                            ),
                    child: const Text('New patient? Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
