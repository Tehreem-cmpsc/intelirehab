import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../onboarding/onboarding_data.dart' show genderOptions;
import '../onboarding/onboarding_repository.dart';
import '../onboarding/widgets/form_widgets.dart';
import 'profile_models.dart';
import 'profile_repository.dart';

/// Asks before throwing away typed changes (Rule 24 — back never silently
/// discards entered data). Shared by the Profile editors.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text("You've made changes that haven't been saved."),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep editing')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
      ],
    ),
  );
  return discard == true;
}

/// Personal Info editor. Pickers before free text (Rule 25): date picker
/// for DOB, chips for gender, numeric keyboards for phone/height/weight.
/// Save sits in the thumb zone (Rule 21). Limits match the database's own
/// check constraints (supabase_patient_profile_self_edit.sql), so bad input
/// is caught here in plain language rather than as a server error.
class EditPersonalInfoScreen extends StatefulWidget {
  final ProfileData data;
  final ProfileRepository repo;
  const EditPersonalInfoScreen({super.key, required this.data, required this.repo});

  @override
  State<EditPersonalInfoScreen> createState() => _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends State<EditPersonalInfoScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.data.name);
  late final _phone = TextEditingController(text: widget.data.phone);
  // Shown as stored (170.5 stays 170.5): rounding here would silently change
  // the value the next time ANY field is saved.
  static String _measure(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toString());
  late final _height = TextEditingController(text: _measure(widget.data.heightCm));
  late final _weight = TextEditingController(text: _measure(widget.data.weightKg));
  late DateTime? _dob = widget.data.dateOfBirth;
  late String? _gender = widget.data.gender;
  bool _saving = false;
  String? _error;

  bool get _dirty {
    final d = widget.data;
    return _name.text.trim() != d.name ||
        _phone.text.trim() != d.phone ||
        _height.text.trim() != (d.heightCm?.round().toString() ?? '') ||
        _weight.text.trim() != (d.weightKg?.round().toString() ?? '') ||
        _dob != d.dateOfBirth ||
        _gender != d.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _height.dispose();
    _weight.dispose();
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
          .saveProfile(
            name: _name.text,
            phone: _phone.text,
            dateOfBirth: _dob,
            gender: _gender,
            heightCm: double.tryParse(_height.text.trim()),
            weightKg: double.tryParse(_weight.text.trim()),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OnboardingException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? Function(String?) _range(String what, int max) => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null; // optional
        final n = int.tryParse(t);
        if (n == null || n <= 0 || n >= max) return 'Enter a $what between 1 and ${max - 1}.';
        return null;
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Personal info')),
        body: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              QuestionBlock(
                title: 'Full name',
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline, size: 20)),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                ),
              ),
              QuestionBlock(
                title: 'Mobile number',
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.isNotEmpty && digits.length < 10 ? 'Enter a valid mobile number' : null;
                  },
                ),
              ),
              QuestionBlock(
                title: 'Date of birth',
                child: DateField(
                  value: _dob,
                  hint: 'Select date',
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                  initialDate: DateTime(DateTime.now().year - 30),
                  onChanged: (v) => setState(() => _dob = v),
                ),
              ),
              QuestionBlock(
                title: 'Gender',
                child: ChipChoice(
                  options: genderOptions,
                  selected: _gender,
                  onSelected: (v) => setState(() => _gender = v),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: QuestionBlock(
                      title: 'Height',
                      child: TextFormField(
                        controller: _height,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(suffixText: 'cm', hintText: 'Optional'),
                        validator: _range('height', 300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QuestionBlock(
                      title: 'Weight',
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(suffixText: 'kg', hintText: 'Optional'),
                        validator: _range('weight', 500),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) InfoBanner(icon: Icons.error_outline, text: _error!, tone: BannerTone.warning),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 15, color: c.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Email can\'t be changed here — it\'s your sign-in. Contact your clinic to update it.',
                      style: TextStyle(fontSize: 12, color: c.muted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            FilledButton(
              onPressed: _saving || !_dirty ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
