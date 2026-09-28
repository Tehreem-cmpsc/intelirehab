import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../onboarding_data.dart';
import '../widgets/arm_diagram.dart';
import '../widgets/form_widgets.dart';

class InjuryDetailsStep extends StatelessWidget {
  final OnboardingData data;
  final bool showErrors;

  const InjuryDetailsStep({super.key, required this.data, required this.showErrors});

  String? _missing(Object? value, String message) => showErrors && value == null ? message : null;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionBlock(
          title: 'Which arm is injured?',
          error: _missing(data.affectedSide, 'Choose an arm'),
          child: SegmentedChoice(
            options: sideOptions,
            selected: data.affectedSide,
            onSelected: (v) => data.update(() => data.affectedSide = v),
          ),
        ),
        QuestionBlock(
          title: 'Where is the injury?',
          helper: 'Tap the diagram or choose below.',
          error: _missing(data.affectedJoint, 'Choose an area'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArmDiagram(
                side: data.affectedSide,
                selected: data.affectedJoint,
                onSelected: (v) => data.update(() => data.affectedJoint = v),
              ),
              const SizedBox(height: 10),
              SegmentedChoice(
                options: jointOptions,
                selected: data.affectedJoint,
                onSelected: (v) => data.update(() => data.affectedJoint = v),
              ),
            ],
          ),
        ),
        QuestionBlock(
          title: 'What kind of injury is it?',
          helper: 'Your best guess is fine — your physiotherapist will confirm.',
          error: _missing(data.injuryType, 'Choose one'),
          child: OptionGrid(
            options: injuryTypeOptions,
            selected: data.injuryType,
            onSelected: (v) => data.update(() => data.injuryType = v),
          ),
        ),
        QuestionBlock(
          title: 'How did it happen?',
          error: _missing(data.injuryCause, 'Choose one'),
          child: ChipChoice(
            options: injuryCauseOptions,
            selected: data.injuryCause,
            onSelected: (v) => data.update(() => data.injuryCause = v),
          ),
        ),
        QuestionBlock(
          title: 'When did it happen?',
          error: _missing(data.injuryDate, 'Choose the date of injury'),
          child: DateField(
            value: data.injuryDate,
            hint: 'Select date',
            firstDate: DateTime(now.year - 20),
            lastDate: now,
            hasError: showErrors && data.injuryDate == null,
            onChanged: (d) => data.update(() => data.injuryDate = d),
          ),
        ),
        QuestionBlock(
          title: 'Is this the first time you have injured this arm?',
          error: _missing(data.firstInjury, 'Choose one'),
          child: SegmentedChoice(
            options: const [Option('yes', 'Yes, first time'), Option('no', 'No, it happened before')],
            selected: data.firstInjury == null ? null : (data.firstInjury! ? 'yes' : 'no'),
            onSelected: (v) => data.update(() => data.firstInjury = v == 'yes'),
          ),
        ),
        QuestionBlock(
          title: 'How much does it hurt today?',
          error: _missing(data.painLevel, 'Choose a pain level'),
          child: _PainScale(
            value: data.painLevel,
            onChanged: (v) => data.update(() => data.painLevel = v),
          ),
        ),
      ],
    );
  }
}

/// 0–3 scale, colour-coded from success to alert like the portal's status
/// colours. Each level is its own tappable cell.
class _PainScale extends StatelessWidget {
  final int? value;
  final ValueChanged<int> onChanged;

  const _PainScale({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tones = [c.success, Color.lerp(c.success, c.accent, 0.6)!, c.accent, c.alert];
    return Row(
      children: [
        for (var i = 0; i < painOptions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: SelectableCard(
              selected: value == i,
              showCheck: false,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              onTap: () => onChanged(i),
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == i ? tones[i] : tones[i].withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: value == i ? Colors.white : tones[i],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(painOptions[i].label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
