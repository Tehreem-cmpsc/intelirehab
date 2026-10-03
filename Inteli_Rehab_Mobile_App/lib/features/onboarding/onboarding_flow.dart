import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../../app.dart' show AuthGate;
import 'confirm_email_screen.dart';
import 'onboarding_data.dart';
import 'onboarding_repository.dart';
import 'steps/calibration_step.dart';
import 'steps/clinic_physio_step.dart';
import 'steps/contact_step.dart';
import 'steps/injury_details_step.dart';
import 'steps/personal_details_step.dart';
import 'steps/wearable_setup_step.dart';
import 'waiting_for_physio_screen.dart';
import 'widgets/onboarding_header.dart';

class _StepMeta {
  final String eyebrow;
  final String title;
  final String subtitle;
  const _StepMeta(this.eyebrow, this.title, this.subtitle);
}

const _steps = [
  _StepMeta('PERSONAL DETAILS', 'Tell us about you', 'This helps your physiotherapist tailor your plan.'),
  _StepMeta('INJURY DETAILS', 'About your injury', 'A few quick questions about what happened.'),
  _StepMeta('CONTACT', 'Create your account', 'How your clinic reaches you, and how you sign in.'),
  _StepMeta(
      'CLINIC & PHYSIOTHERAPIST', 'Choose your care team', 'Pick the clinic and physiotherapist you’ll work with.'),
  _StepMeta('WEARABLE SETUP', 'Pair your Inteli Band', 'The band measures your movement during exercises.'),
  _StepMeta('CALIBRATION', 'Calibrate your band', 'A guided calibration that records how your arm moves today.'),
];

/// Total including the final "wait for physiotherapist" screen.
const _stepCount = 7;

/// Patient onboarding, steps 1–6. Step 7 (waiting for approval) is its own
/// screen that replaces this one once everything is submitted.
///
/// Each step is saved to Supabase when the patient taps Continue — see
/// [OnboardingRepository] for which table each one lands in. Once the
/// account exists (after step 3) the earlier steps are locked; closing
/// the flow then signs out, and the patient resumes at the clinic step
/// next time they sign in (AuthGate).
class OnboardingFlow extends StatefulWidget {
  /// Answers restored from the database when resuming.
  final OnboardingData? initialData;
  final int initialStep;
  final OnboardingRepository? repository;

  const OnboardingFlow({super.key, this.initialData, this.initialStep = 0, this.repository});

  /// First step after the account is created.
  static const firstPostAccountStep = 3;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final _data = widget.initialData ?? OnboardingData();
  late final _repo = widget.repository ?? OnboardingRepository();
  final _formKeys = List.generate(_steps.length, (_) => GlobalKey<FormState>());
  late int _index = widget.initialStep;
  bool _showErrors = false;
  bool _forward = true;
  bool _busy = false;

  /// Earliest step the patient may go back to.
  int get _minIndex => _data.patientId != null ? OnboardingFlow.firstPostAccountStep : 0;

  bool get _atLockedStart => _index <= _minIndex && _minIndex > 0;

  @override
  void dispose() {
    // Always free the Bluetooth link (even when the data object outlives the
    // flow, as when resuming) so Home can connect to the band afterwards.
    if (widget.initialData == null) {
      _data.dispose();
    } else {
      unawaited(_data.releaseBand());
    }
    super.dispose();
  }

  bool get _canContinue =>
      !_busy &&
      switch (_index) {
        4 => _data.wearable != null && _data.bandLinked, // the band is compulsory AND must be linked now
        // Calibration is compulsory: the whole sequence, muscle check included.
        5 => _data.baseline != null && (_data.musclesCalibrated || _data.baselineSaved),
        _ => true,
      };

  bool _validateCurrent() {
    final formOk = _formKeys[_index].currentState?.validate() ?? true;
    final choicesOk = switch (_index) {
      0 => _data.personalChoicesComplete,
      1 => _data.injuryChoicesComplete,
      2 => _data.termsAccepted,
      3 => _data.clinic != null && _data.physio != null,
      _ => true,
    };
    return formOk && choicesOk;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!_validateCurrent()) {
      setState(() => _showErrors = true);
      _snack('Please answer the highlighted questions.');
      return;
    }

    setState(() => _busy = true);
    bool advance;
    try {
      advance = await _saveCurrentStep();
    } on OnboardingException catch (e) {
      if (mounted) _snack(e.message);
      advance = false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || !advance) return;

    if (_index == _steps.length - 1) {
      // Someone sent back here to finish calibrating may already be approved:
      // let AuthGate route them (it re-checks the baseline too), not the waiting screen.
      var approved = false;
      try {
        approved = (await AuthService().fetchMyPatientRow())?['approved'] == true;
      } catch (_) {
        // Offline: the waiting screen's own status check will sort it out.
      }
      if (!mounted) return;
      if (approved) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => WaitingForPhysioScreen(data: _data)));
      }
      return;
    }
    _goTo(_index + 1);
  }

  /// Saves the current step. Returns false if the flow shouldn't advance
  /// (it has navigated somewhere else instead).
  Future<bool> _saveCurrentStep() async {
    switch (_index) {
      case 2:
        if (_data.patientId != null) return true;
        final result = await _repo.createAccount(_data);
        if (result == SignUpResult.needsEmailConfirmation) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ConfirmEmailScreen(email: _data.email)),
            );
          }
          return false;
        }
      case 3:
        await _repo.chooseClinicAndPhysio(_data.clinic!, _data.physio!);
      case 4:
        final device = _data.wearable;
        if (device != null) _data.deviceRecordId = await _repo.saveWearable(_data.patientId!, device);
      case 5:
        final baseline = _data.baseline;
        if (baseline != null && !_data.baselineSaved) {
          await _repo.saveBaseline(
            patientId: _data.patientId!,
            deviceRecordId: _data.wearable != null ? _data.deviceRecordId : null,
            baseline: baseline,
            reps: CalibrationStep.reps,
          );
          _data.baselineSaved = true;
        }
    }
    return true;
  }

  void _goTo(int index) {
    setState(() {
      _forward = index > _index;
      _index = index;
      _showErrors = false;
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_busy) return;
    if (_atLockedStart) {
      _confirmLeave();
    } else if (_index == 0) {
      Navigator.of(context).maybePop();
    } else {
      _goTo(_index - 1);
    }
  }

  /// After the account exists, leaving means signing out; progress so far
  /// is saved and resumes on next sign-in.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish later?'),
        content: const Text(
          'Your account and answers so far are saved. Sign in again any time to pick up where you left off.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    final navigator = Navigator.of(context);
    await AuthService().signOut();
    navigator.popUntil((r) => r.isFirst);
  }

  Widget _stepBody() {
    return switch (_index) {
      0 => PersonalDetailsStep(data: _data, showErrors: _showErrors),
      1 => InjuryDetailsStep(data: _data, showErrors: _showErrors),
      2 => ContactStep(data: _data, showErrors: _showErrors),
      3 => ClinicPhysioStep(data: _data, showErrors: _showErrors, repository: _repo),
      4 => WearableSetupStep(data: _data),
      _ => CalibrationStep(data: _data, onBackToWearable: () => _goTo(4)),
    };
  }

  String get _continueLabel => switch (_index) {
        2 => 'Create account',
        5 => 'Finish',
        _ => 'Continue',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = _steps[_index];

    return PopScope(
      canPop: _index == 0 && _minIndex == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _data,
          builder: (context, _) => Column(
            children: [
              OnboardingHeader(
                stepIndex: _index,
                stepCount: _stepCount,
                eyebrow: 'STEP ${_index + 1} OF $_stepCount · ${meta.eyebrow}',
                title: meta.title,
                subtitle: meta.subtitle,
                onBack: _back,
                backIcon: _atLockedStart ? Icons.close : Icons.arrow_back,
                backTooltip: _atLockedStart ? 'Finish later' : 'Back',
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(_index);
                    final dx = (incoming == _forward) ? 0.08 : -0.08;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    key: ValueKey(_index),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Form(key: _formKeys[_index], child: _stepBody()),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SafeArea(
                  top: false,
                  child: FilledButton(
                    onPressed: _canContinue ? _next : null,
                    child: _busy
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: c.onPrimary),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_continueLabel),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
