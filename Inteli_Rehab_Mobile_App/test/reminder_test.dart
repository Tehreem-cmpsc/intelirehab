// The daily exercise reminder: how a plan's frequency becomes a gap in days, and the settings card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/profile/reminder_card.dart';
import 'package:inteli_rehab_mobile_app/features/reminders/reminder_service.dart';

class _FakeBackend implements ReminderBackend {
  ReminderSettings settings;
  bool permission;
  final calls = <String>[];
  _FakeBackend({this.settings = const ReminderSettings(), this.permission = true});

  @override
  Future<ReminderSettings> read() async => settings;
  @override
  Future<bool> ensurePermission() async {
    calls.add('permission');
    return permission;
  }

  @override
  Future<void> enable(ReminderSettings s) async {
    calls.add('enable ${s.hour}:${s.minute} every ${s.intervalDays}');
    settings = s.copyWith(enabled: true);
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
    settings = settings.copyWith(enabled: false);
  }

  @override
  Future<void> setIntervalDays(int days) async => calls.add('interval $days');
  @override
  Future<void> markSessionDone() async => calls.add('done');
}

Widget _host(Widget child) => MaterialApp(theme: AppTheme.light(), home: Scaffold(body: ListView(children: [child])));

void main() {
  group('how often a plan asks for a session', () {
    test('the portal\'s four frequencies', () {
      expect(intervalDaysFor('Daily'), 1);
      expect(intervalDaysFor('Every other day'), 2);
      expect(intervalDaysFor('3× per week'), 2);
      expect(intervalDaysFor('Weekly'), 7);
    });

    test('anything unknown or missing counts as daily, so a reminder is never missed', () {
      expect(intervalDaysFor(null), 1);
      expect(intervalDaysFor(''), 1);
      expect(intervalDaysFor('whenever'), 1);
    });

    test('the most demanding exercise on the plan decides', () {
      expect(planIntervalDays(['Weekly', 'Every other day']), 2);
      expect(planIntervalDays(['Weekly', 'Weekly']), 7);
      expect(planIntervalDays(['Weekly', null]), 1);
      expect(planIntervalDays(const []), 1);
    });
  });

  group('ReminderSettings', () {
    test('reads as a 12-hour time', () {
      expect(const ReminderSettings(hour: 18, minute: 5).label(), '6:05 PM');
      expect(const ReminderSettings(hour: 0, minute: 0).label(), '12:00 AM');
      expect(const ReminderSettings(hour: 12, minute: 30).label(), '12:30 PM');
      expect(const ReminderSettings(hour: 9, minute: 45).label(), '9:45 AM');
    });
  });

  group('ReminderService', () {
    test('passes the finished session and the plan frequency to the phone', () async {
      final fake = _FakeBackend();
      ReminderService.useBackend(fake);
      ReminderService.sessionDone();
      ReminderService.syncPlanFrequencies(['Weekly']);
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls, containsAll(['done', 'interval 7']));
    });

    test('never throws if the phone side is missing', () async {
      ReminderService.useBackend(PlatformReminderBackend()); // no channel in a test
      ReminderService.sessionDone();
      ReminderService.syncPlanFrequencies(['Daily']);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });

  group('ReminderCard', () {
    testWidgets('starts off, and turning it on asks permission, then sets the alarm', (tester) async {
      final fake = _FakeBackend();
      await tester.pumpWidget(_host(ReminderCard(backend: fake)));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(find.text('Time'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();
      expect(fake.calls, ['permission', 'enable 18:0 every 1']);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      expect(find.text('6:00 PM'), findsOneWidget);
      expect(find.text('Reminder set for 6:00 PM.'), findsOneWidget);
    });

    testWidgets('a plan on a weekly cycle keeps its gap when the reminder is turned on', (tester) async {
      final fake = _FakeBackend(settings: const ReminderSettings(intervalDays: 7));
      await tester.pumpWidget(_host(ReminderCard(backend: fake)));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();
      expect(fake.calls.last, 'enable 18:0 every 7');
    });

    testWidgets('if the patient refuses notifications it stays off and says why', (tester) async {
      final fake = _FakeBackend(permission: false);
      await tester.pumpWidget(_host(ReminderCard(backend: fake)));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();
      expect(fake.calls, ['permission'], reason: 'no alarm was set');
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(find.textContaining('Notifications are off for this app'), findsOneWidget);
    });

    testWidgets('an existing reminder shows its time, and turning it off cancels the alarm', (tester) async {
      final fake = _FakeBackend(settings: const ReminderSettings(enabled: true, hour: 7, minute: 30));
      await tester.pumpWidget(_host(ReminderCard(backend: fake)));
      await tester.pump();
      expect(find.text('7:30 AM'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();
      expect(fake.calls, ['disable']);
      expect(find.text('Time'), findsNothing);
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
          body: ListView(children: [ReminderCard(backend: _FakeBackend(settings: const ReminderSettings(enabled: true)))]),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
