import 'package:flutter/material.dart';

import 'package:flutter/gestures.dart';

import '../../../core/legal/legal_text.dart';
import '../../../core/theme/app_theme.dart';
import '../onboarding_data.dart';
import '../widgets/form_widgets.dart';

/// Same rule as the portal's infrastructure/validation/password.js, so
/// patients and staff are held to one bar.
String? passwordError(String? password) {
  if (password == null || password.isEmpty) return 'Password is required.';
  if (password.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[a-zA-Z]').hasMatch(password)) return 'Include at least one letter.';
  if (!RegExp(r'[0-9]').hasMatch(password)) return 'Include at least one number.';
  return null;
}

class ContactStep extends StatefulWidget {
  final OnboardingData data;
  final bool showErrors;

  const ContactStep({super.key, required this.data, required this.showErrors});

  @override
  State<ContactStep> createState() => _ContactStepState();
}

class _ContactStepState extends State<ContactStep> {
  bool _obscure = true;
  String _confirm = '';

  // Tapping the links opens the text without toggling the checkbox.
  late final _termsTap = TapGestureRecognizer()..onTap = () => LegalPage.open(context, 'Terms of Use', termsText);
  late final _privacyTap = TapGestureRecognizer()..onTap = () => LegalPage.open(context, 'Privacy Policy', privacyText);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  OnboardingData get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionBlock(
            title: 'Mobile number',
            helper: 'Your clinic may call you about appointments.',
            child: TextFormField(
              initialValue: data.phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. 0300 1234567',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
              onChanged: (v) => data.phone = v,
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 10 ? 'Enter a valid mobile number' : null;
              },
            ),
          ),
          QuestionBlock(
            title: 'Email',
            child: TextFormField(
              initialValue: data.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
              onChanged: (v) => data.email = v.trim(),
              validator: (v) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
            ),
          ),
          QuestionBlock(
            title: 'Create a password',
            child: TextFormField(
              initialValue: data.password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
              onChanged: (v) => setState(() => data.password = v),
              validator: passwordError,
            ),
          ),
          _PasswordChecklist(password: data.password),
          const SizedBox(height: 16),
          QuestionBlock(
            title: 'Confirm password',
            child: TextFormField(
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
              onChanged: (v) => _confirm = v,
              validator: (_) => _confirm != data.password ? 'Passwords do not match' : null,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => data.update(() => data.termsAccepted = !data.termsAccepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: data.termsAccepted,
                    onChanged: (v) => data.update(() => data.termsAccepted = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                              text: 'Terms of Use',
                              recognizer: _termsTap,
                              style: TextStyle(
                                  color: c.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                          const TextSpan(text: ' and '),
                          TextSpan(
                              text: 'Privacy Policy',
                              recognizer: _privacyTap,
                              style: TextStyle(
                                  color: c.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                          const TextSpan(text: ', and to sharing my rehab data with the clinic I choose.'),
                        ]),
                        style: TextStyle(fontSize: 13, color: c.ink, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showErrors && !data.termsAccepted)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text('Please accept to continue', style: TextStyle(fontSize: 12, color: c.alert)),
            ),
          const SizedBox(height: 16),
          const InfoBanner(
            icon: Icons.info_outline,
            text: "You'll use this email and password to sign in to the app.",
          ),
        ],
      ),
    );
  }
}

class _PasswordChecklist extends StatelessWidget {
  final String password;
  const _PasswordChecklist({required this.password});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rules = [
      ('8+ characters', password.length >= 8),
      ('A letter', RegExp(r'[a-zA-Z]').hasMatch(password)),
      ('A number', RegExp(r'[0-9]').hasMatch(password)),
    ];
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final (label, ok) in rules)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: ok ? c.success : c.muted),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: ok ? c.success : c.muted)),
              ],
            ),
        ],
      ),
    );
  }
}
