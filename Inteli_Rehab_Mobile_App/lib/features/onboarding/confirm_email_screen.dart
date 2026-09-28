import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/theme_toggle.dart';
import '../auth/login_screen.dart';

/// Shown after sign-up when the Supabase project requires email
/// confirmation. The onboarding answers were saved with the sign-up
/// (auth user metadata), and AuthGate finishes registration on the
/// patient's first sign-in, then resumes at the clinic step.
class ConfirmEmailScreen extends StatelessWidget {
  final String email;

  const ConfirmEmailScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [ThemeToggle(), SizedBox(width: 16)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: c.primaryTint, shape: BoxShape.circle),
                  child: Icon(Icons.mark_email_unread_outlined, size: 40, color: c.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text('Confirm your email', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'We sent a confirmation link to '),
                  TextSpan(text: email, style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
                  const TextSpan(
                    text: '. Open it, then sign in here to choose your clinic and finish setting up. '
                        "Your answers so far are saved.",
                  ),
                ]),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.5, color: c.muted),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LoginScreen(initialEmail: email)),
                ),
                child: const Text("I've confirmed — sign in"),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Back to start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
