// The physiotherapist's warning shown on Home and before an exercise, with a "Got it" receipt.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/widgets/warning_banner.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('shows nothing when there is no warning', (tester) async {
    await tester.pumpWidget(_host(WarningBanner(patientId: 'p1', load: () async => null)));
    await tester.pump();
    expect(find.text('Message from your physiotherapist'), findsNothing);
    expect(find.text('Got it'), findsNothing);
  });

  testWidgets('shows nothing, and no error, when the warning cannot be loaded', (tester) async {
    await tester.pumpWidget(_host(WarningBanner(patientId: 'p1', load: () async => throw Exception('offline'))));
    await tester.pump();
    expect(find.text('Message from your physiotherapist'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the warning, and "Got it" tells the physiotherapist it was seen', (tester) async {
    var acknowledged = 0;
    await tester.pumpWidget(_host(WarningBanner(
      patientId: 'p1',
      load: () async => const WarningState('Please reduce the intensity.'),
      acknowledge: () async => acknowledged++,
    )));
    await tester.pump();
    expect(find.text('Please reduce the intensity.'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(acknowledged, 1);
    expect(find.text('Got it'), findsNothing);
    expect(find.text('Please reduce the intensity.'), findsOneWidget, reason: 'the warning stays until a session clears it');
    expect(find.textContaining('can see you read this'), findsOneWidget);
  });

  testWidgets('a warning that was already acknowledged has no button', (tester) async {
    await tester.pumpWidget(_host(WarningBanner(
      patientId: 'p1',
      load: () async => const WarningState('Rest today.', seen: true),
    )));
    await tester.pump();
    expect(find.text('Rest today.'), findsOneWidget);
    expect(find.text('Got it'), findsNothing);
  });

  testWidgets('a failed receipt does not hide the warning or throw', (tester) async {
    await tester.pumpWidget(_host(WarningBanner(
      patientId: 'p1',
      load: () async => const WarningState('Rest today.'),
      acknowledge: () async => throw Exception('offline'),
    )));
    await tester.pump();
    await tester.tap(find.text('Got it'));
    await tester.pump();
    expect(find.text('Rest today.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out at 200% text without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0), disableAnimations: true),
        child: c!,
      ),
      home: Scaffold(
        body: WarningBanner(
          patientId: 'p1',
          load: () async => const WarningState('Please keep your movements within a comfortable range.'),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
