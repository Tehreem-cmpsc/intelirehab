import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import 'onboarding_data.dart';
import 'widgets/form_widgets.dart';
import 'widgets/onboarding_header.dart';

/// Last step of onboarding: everything is submitted and the patient waits
/// for their physiotherapist to approve them (patients.approved).
class WaitingForPhysioScreen extends StatefulWidget {
  final OnboardingData data;

  const WaitingForPhysioScreen({super.key, required this.data});

  @override
  State<WaitingForPhysioScreen> createState() => _WaitingForPhysioScreenState();
}

class _WaitingForPhysioScreenState extends State<WaitingForPhysioScreen> with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app is the likely moment approval has happened, so
  /// check quietly instead of making the patient tap "check status".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_checking) _checkStatus(silent: true);
  }

  OnboardingData get data => widget.data;

  Future<void> _checkStatus({bool silent = false}) async {
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final row = await AuthService().fetchMyPatientRow();
      if (row?['approved'] == true) {
        // A fresh AuthGate resolves straight to the home screen.
        navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
        return;
      }
      if (!silent) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Still waiting for approval — we’ll let you know.')));
      }
    } catch (_) {
      if (silent) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't check right now. Try again in a moment.")));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await AuthService().signOut();
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final physio = data.physio;
    final firstName = data.fullName.trim().split(' ').first;

    final items = <_TimelineItem>[
      const _TimelineItem('Personal details', _ItemState.done),
      const _TimelineItem('Injury details', _ItemState.done),
      const _TimelineItem('Account created', _ItemState.done),
      _TimelineItem(
        physio == null ? 'Clinic & physiotherapist' : '${physio.fullName} selected',
        _ItemState.done,
      ),
      _TimelineItem(
        data.wearable != null ? 'Band paired' : 'Band not paired yet',
        data.wearable != null ? _ItemState.done : _ItemState.later,
      ),
      _TimelineItem(
        data.baseline != null ? 'Baseline recorded' : 'Baseline not recorded yet',
        data.baseline != null ? _ItemState.done : _ItemState.later,
      ),
      const _TimelineItem('Physiotherapist review', _ItemState.current),
    ];

    // Nothing to go back to once submitted; still let the app close when
    // this is the root screen.
    return PopScope(
      canPop: !Navigator.of(context).canPop(),
      child: Scaffold(
        body: Column(
          children: [
            OnboardingHeader(
              stepIndex: 6,
              stepCount: 7,
              eyebrow: 'STEP 7 OF 7 · ALMOST THERE',
              title: firstName.isEmpty ? "You're all set" : "You're all set, $firstName",
              subtitle: 'Your physiotherapist now reviews your details before your plan starts.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: c.primaryTint,
                              child: Text(physio?.initials ?? '?',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: c.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(physio?.fullName ?? 'Your physiotherapist',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
                                  if (data.clinic != null)
                                    Text(data.clinic!.name, style: TextStyle(fontSize: 12.5, color: c.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            StatusPill(
                              label: 'Pending review',
                              color: c.accent,
                              background: c.accent.withValues(alpha: 0.14),
                            ),
                            const Spacer(),
                            const _PulsingDot(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your progress', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        for (var i = 0; i < items.length; i++)
                          _TimelineRow(item: items[i], isLast: i == items.length - 1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InfoBanner(
                    icon: Icons.notifications_active_outlined,
                    text: '${physio?.fullName ?? 'Your physiotherapist'} will review your injury details'
                        '${data.baseline != null ? ' and baseline' : ''}, then set up your first exercise plan. '
                        "We'll notify you as soon as it's ready.",
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _checking ? null : _checkStatus,
                    icon: _checking
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    label: const Text('Check status'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ItemState { done, later, current }

class _TimelineItem {
  final String label;
  final _ItemState state;
  const _TimelineItem(this.label, this.state);
}

class _TimelineRow extends StatelessWidget {
  final _TimelineItem item;
  final bool isLast;
  const _TimelineRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color, bg) = switch (item.state) {
      _ItemState.done => (Icons.check, c.success, c.successTint),
      _ItemState.later => (Icons.schedule, c.accent, c.accent.withValues(alpha: 0.14)),
      _ItemState.current => (Icons.hourglass_top, c.primary, c.primaryTint),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: color),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: c.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: item.state == _ItemState.current ? FontWeight.w700 : FontWeight.w500,
                  color: item.state == _ItemState.current ? c.primary : c.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        FadeTransition(
          opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
          child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 6),
        Text('Waiting', style: TextStyle(fontSize: 12, color: c.muted)),
      ],
    );
  }
}
