import 'package:flutter/material.dart';

import '../../core/network/load_guard.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/ui_kit.dart';
import '../home/wearable_connection_controller.dart';
import '../onboarding/onboarding_data.dart' show Option, genderOptions, labelFor;
import '../onboarding/widgets/form_widgets.dart' show DateField, SegmentedChoice;
import 'change_password_screen.dart';
import 'edit_personal_info_screen.dart';
import 'profile_models.dart';
import 'profile_repository.dart';

/// Profile / Settings — not specified in the SRS (gap #4), so this is
/// built strictly from existing PATIENT / WEARABLE_DEVICE fields rather
/// than padded with invented settings (Rule 1). Grouped settings-list
/// layout; editors open as their own screens with Save in the thumb zone.
/// No in-app text-size setting: the OS's scaling is honoured instead
/// (Rules 13/28 — one accessibility system, not two).
class ProfileScreen extends StatefulWidget {
  final String name;
  final WearableConnectionController connection;
  final VoidCallback onSignOut;

  const ProfileScreen({super.key, required this.name, required this.connection, required this.onSignOut});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ProfileRepository();
  late Future<ProfileData> _future = _load();

  Future<ProfileData> _load() => _repo.load().guarded();
  void _reload() => setState(() => _future = _load());

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _editPersonalInfo(ProfileData data) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditPersonalInfoScreen(data: data, repo: _repo)),
    );
    if (saved == true && mounted) {
      _toast('Personal info saved.');
      _reload();
    }
  }

  Future<void> _changePassword() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChangePasswordScreen(repo: _repo)),
    );
    if (saved == true && mounted) _toast('Password updated.');
  }

  Future<void> _forgetWearable(PairedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this wearable?'),
        content: const Text("You'll need to pair it again before your next session."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: context.colors.alert),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.forgetDevice(device.id).guarded();
      widget.connection.forget();
      if (!mounted) return;
      _toast('Wearable forgotten.');
      _reload();
    } catch (e) {
      if (mounted) _toast(friendlyError(e, fallback: "Couldn't forget the wearable."));
    }
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<ProfileData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return MessageState(
              icon: Icons.cloud_off_outlined,
              isError: true,
              title: "Couldn't load your profile",
              text: friendlyError(snap.error!),
              actionLabel: 'Try again',
              onAction: _reload,
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _IdentityCard(name: d.name.isEmpty ? widget.name : d.name, email: d.email),
                const SizedBox(height: 22),
                const SectionLabel('Appearance'),
                const _AppearanceCard(),
                const SizedBox(height: 22),
                SectionLabel(
                  'Personal info',
                  trailing: TextButton.icon(
                    onPressed: () => _editPersonalInfo(d),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                _Group(children: [
                  _Row(icon: Icons.phone_outlined, label: 'Phone', value: d.phone.isEmpty ? '—' : d.phone),
                  _Row(
                    icon: Icons.cake_outlined,
                    label: 'Date of birth',
                    value: d.dateOfBirth == null ? '—' : DateField.format(d.dateOfBirth!),
                  ),
                  _Row(icon: Icons.wc_outlined, label: 'Gender', value: labelFor(genderOptions, d.gender) ?? '—'),
                  _Row(
                      icon: Icons.height,
                      label: 'Height',
                      value: d.heightCm == null ? '—' : '${d.heightCm!.round()} cm'),
                  _Row(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight',
                    value: d.weightKg == null ? '—' : '${d.weightKg!.round()} kg',
                  ),
                ]),
                const SizedBox(height: 22),
                const SectionLabel('Care team'),
                _Group(children: [
                  _Row(icon: Icons.local_hospital_outlined, label: 'Clinic', value: d.clinicName ?? 'Not chosen yet'),
                  _Row(
                      icon: Icons.person_pin_outlined,
                      label: 'Physiotherapist',
                      value: d.physioName ?? 'Not chosen yet'),
                ]),
                const _Footnote('To change your clinic or physiotherapist, please contact your clinic.'),
                const SizedBox(height: 22),
                const SectionLabel('Wearable'),
                if (d.device == null)
                  const _Group(children: [
                    _Row(icon: Icons.watch_outlined, label: 'No wearable paired', value: ''),
                  ])
                else
                  _Group(children: [
                    _Row(icon: Icons.watch_outlined, label: 'Device', value: d.device!.displayName),
                    _Row(icon: Icons.qr_code_2, label: 'Serial', value: d.device!.serial),
                    _Row(icon: Icons.system_update_alt, label: 'Firmware', value: d.device!.firmware ?? '—'),
                    _Row(icon: Icons.battery_std, label: 'Battery', value: '${d.device!.batteryPercent}%'),
                    _Row(
                      icon: Icons.link_off,
                      label: 'Forget wearable',
                      destructive: true,
                      onTap: () => _forgetWearable(d.device!),
                    ),
                  ]),
                const SizedBox(height: 22),
                const SectionLabel('Account & security'),
                _Group(children: [
                  _Row(icon: Icons.mail_outline, label: 'Email', value: d.email),
                  _Row(icon: Icons.lock_outline, label: 'Change password', onTap: _changePassword),
                  _Row(icon: Icons.logout, label: 'Log out', destructive: true, onTap: _logOut),
                ]),
                const _Footnote(
                    "Your email is your sign-in, so changing it needs a verified step — contact your clinic."),
                const SizedBox(height: 22),
                const SectionLabel('About'),
                _Group(children: [
                  _Row(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => _openLegal('Terms & Conditions', _termsText),
                  ),
                  _Row(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy notice',
                    onTap: () => _openLegal('Privacy notice', _privacyText),
                  ),
                  const _Row(icon: Icons.info_outline, label: 'App version', value: _appVersion),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openLegal(String title, String body) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _LegalPage(title: title, body: body)));
  }
}

// Kept in step with pubspec.yaml's `version:` by hand — no
// package_info_plus dependency for one read-only line.
const _appVersion = '0.1.0';

class _IdentityCard extends StatelessWidget {
  final String name;
  final String email;
  const _IdentityCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.headerStart, c.headerEnd]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              initialsOf(name),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Light / Dark / System, first thing in Settings so it's clearly visible
/// (Rule 32 — light sensitivity is common after injury or surgery).
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => SegmentedChoice(
          options: const [
            Option('system', 'System', icon: Icons.brightness_auto_outlined),
            Option('light', 'Light', icon: Icons.light_mode_outlined),
            Option('dark', 'Dark', icon: Icons.dark_mode_outlined),
          ],
          selected: switch (controller.value) {
            ThemeMode.system => 'system',
            ThemeMode.light => 'light',
            ThemeMode.dark => 'dark',
          },
          onSelected: (v) => controller.set(switch (v) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          }),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: c.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One settings row: 48dp+ tap target, icon + label + value or chevron.
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  const _Row({required this.icon, required this.label, this.value, this.onTap, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = destructive ? c.alert : c.ink;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: destructive ? c.alert : c.primary),
          const SizedBox(width: 18),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: fg)),
          ),
          if (value != null && value!.isNotEmpty)
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: c.muted),
              ),
            ),
          if (onTap != null) Icon(Icons.chevron_right, color: c.muted),
        ],
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return Semantics(button: true, child: InkWell(onTap: onTap, child: row));
  }
}

class _Footnote extends StatelessWidget {
  final String text;
  const _Footnote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Text(text, style: TextStyle(fontSize: 12, color: context.colors.muted, height: 1.4)),
    );
  }
}

class _LegalPage extends StatelessWidget {
  final String title;
  final String body;
  const _LegalPage({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(body, style: TextStyle(fontSize: 14.5, color: c.ink, height: 1.6)),
        ),
      ),
    );
  }
}

// Placeholder copy — replace with the clinic's reviewed legal text before
// release. Kept short and generic rather than inventing specific data
// handling or retention claims.
const _termsText = '''
These Terms & Conditions govern your use of the Inteli Rehab app. By using '''
    '''the app you agree to follow your prescribed rehabilitation plan as '''
    '''directed by your physiotherapist, and to use the wearable device and '''
    '''app as intended for home-based rehabilitation tracking.

This app supports, but does not replace, guidance from your clinic. Always '''
    '''follow your physiotherapist's instructions and contact your clinic '''
    '''with any concerns about your treatment.

This is placeholder text pending review by the clinic's legal team.
''';

const _privacyText = '''
This Privacy Notice describes how Inteli Rehab handles your information. '''
    '''We collect the personal, injury and session data you and your '''
    '''wearable device provide in order to support your rehabilitation and '''
    '''share your progress with your clinic and physiotherapist.

Your data is only shared with the clinic and physiotherapist you choose. '''
    '''You can review the personal details you've provided at any time from '''
    '''this Profile screen.

This is placeholder text pending review by the clinic's legal team.
''';
