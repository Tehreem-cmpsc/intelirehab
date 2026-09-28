import 'package:flutter/material.dart';

import '../onboarding_data.dart';
import '../widgets/form_widgets.dart';

class PersonalDetailsStep extends StatelessWidget {
  final OnboardingData data;
  final bool showErrors;

  const PersonalDetailsStep({super.key, required this.data, required this.showErrors});

  String? _missing(Object? value, String message) => showErrors && value == null ? message : null;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionBlock(
          title: 'Full name',
          child: TextFormField(
            initialValue: data.fullName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              hintText: 'e.g. Ayesha Khan',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            onChanged: (v) => data.fullName = v,
            validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
          ),
        ),
        QuestionBlock(
          title: 'Date of birth',
          error: _missing(data.dateOfBirth, 'Choose your date of birth'),
          child: DateField(
            value: data.dateOfBirth,
            hint: 'Select date',
            firstDate: DateTime(now.year - 110),
            lastDate: now,
            initialDate: DateTime(now.year - 30, now.month, now.day),
            hasError: showErrors && data.dateOfBirth == null,
            onChanged: (d) => data.update(() => data.dateOfBirth = d),
          ),
        ),
        QuestionBlock(
          title: 'Gender',
          error: _missing(data.gender, 'Choose one'),
          child: ChipChoice(
            options: genderOptions,
            selected: data.gender,
            onSelected: (v) => data.update(() => data.gender = v),
          ),
        ),
        QuestionBlock(
          title: 'How active are you day to day?',
          helper: 'Before your injury.',
          error: _missing(data.activityLevel, 'Choose one'),
          child: OptionGrid(
            options: activityOptions,
            selected: data.activityLevel,
            onSelected: (v) => data.update(() => data.activityLevel = v),
          ),
        ),
        QuestionBlock(
          title: 'Which hand do you write with?',
          error: _missing(data.dominantArm, 'Choose one'),
          child: SegmentedChoice(
            options: dominantArmOptions,
            selected: data.dominantArm,
            onSelected: (v) => data.update(() => data.dominantArm = v),
          ),
        ),
      ],
    );
  }
}
