import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../onboarding/onboarding_repository.dart';
import '../onboarding/steps/contact_step.dart' show passwordError;
import '../onboarding/widgets/form_widgets.dart';
import 'edit_personal_info_screen.dart' show confirmDiscardChanges;
import 'profile_repository.dart';

/// Change password: re-enter the current one, and BR-2's rules apply again
/// (the same passwordError the sign-up screen uses). Save in the thumb zone;
/// back with anything typed asks first (Rule 24).
class ChangePasswordScreen extends StatefulWidget {
  final ProfileRepository repo;
  const ChangePasswordScreen({super.key, required this.repo});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  bool get _dirty => _current.text.isNotEmpty || _next.text.isNotEmpty || _confirm.text.isNotEmpty;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo
          .changePassword(currentPassword: _current.text, newPassword: _next.text)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      Navigator.of(context).pop(true);
    } on OnboardingException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't update your password. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _toggle() => IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rules = [
      ('8+ characters', _next.text.length >= 8),
      ('A letter', RegExp(r'[a-zA-Z]').hasMatch(_next.text)),
      ('A number', RegExp(r'[0-9]').hasMatch(_next.text)),
    ];

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Change password')),
        body: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                QuestionBlock(
                  title: 'Current password',
                  child: TextFormField(
                    controller: _current,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    decoration:
                        InputDecoration(prefixIcon: const Icon(Icons.lock_outline, size: 20), suffixIcon: _toggle()),
                    validator: (v) => (v ?? '').isEmpty ? 'Enter your current password' : null,
                  ),
                ),
                QuestionBlock(
                  title: 'New password',
                  child: TextFormField(
                    controller: _next,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_reset, size: 20)),
                    validator: passwordError,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      for (final (label, ok) in rules)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 14, color: ok ? c.success : c.muted),
                            const SizedBox(width: 4),
                            Text(label, style: TextStyle(fontSize: 12, color: ok ? c.success : c.muted)),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                QuestionBlock(
                  title: 'Confirm new password',
                  child: TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_reset, size: 20)),
                    validator: (v) => v != _next.text ? 'Passwords do not match' : null,
                  ),
                ),
                if (_error != null) InfoBanner(icon: Icons.error_outline, text: _error!, tone: BannerTone.warning),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            FilledButton(
              onPressed: _saving || !_dirty ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}
