// Day / week / streak maths for Home and Progress. These were wrong for
// anyone not on UTC: server timestamps parse as UTC, so a 02:00 local
// session in Pakistan landed on the previous day.
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/util/dates.dart';
import 'package:inteli_rehab_mobile_app/features/home/home_repository.dart';

void main() {
  group('parseTimestamp', () {
    test('returns a local DateTime, whatever offset the server sent', () {
      final t = parseTimestamp('2026-09-28T21:23:56.229031+00:00');
      expect(t.isUtc, isFalse);
      // Same instant as the UTC value.
      expect(t.toUtc(), DateTime.utc(2026, 9, 28, 21, 23, 56, 229, 31));
    });
  });

  group('startOfWeek', () {
    test('is Monday 00:00 for any day in the week', () {
      final monday = DateTime(2026, 10, 5);
      for (var i = 0; i < 7; i++) {
        expect(startOfWeek(DateTime(2026, 10, 5 + i, 15, 30)), monday);
      }
    });

    test('crosses a month boundary cleanly', () {
      expect(startOfWeek(DateTime(2026, 11, 1)), DateTime(2026, 10, 26)); // Sunday 1 Nov
    });
  });

  group('currentStreak', () {
    final now = DateTime(2026, 10, 7, 9); // Wednesday
    DateTime at(int daysAgo, [int hour = 12]) => DateTime(2026, 10, 7 - daysAgo, hour);

    test('counts consecutive days ending today', () {
      expect(currentStreak([at(0), at(1), at(2)], now: now), 3);
    });
    test('still counts when nothing is logged yet today', () {
      expect(currentStreak([at(1), at(2)], now: now), 2);
    });
    test('stops at the first gap', () {
      expect(currentStreak([at(0), at(2)], now: now), 1);
    });
    test('several sessions on one day count once', () {
      expect(currentStreak([at(0, 8), at(0, 20)], now: now), 1);
    });
    test('is 0 with nothing recent', () {
      expect(currentStreak([at(5)], now: now), 0);
      expect(currentStreak(const [], now: now), 0);
    });
    test('a 00:30 session belongs to that calendar day, not the previous one', () {
      expect(currentStreak([DateTime(2026, 10, 7, 0, 30)], now: now), 1);
    });
  });

  group('calendarDaysBetween', () {
    test('counts calendar days, not 24-hour blocks', () {
      expect(calendarDaysBetween(DateTime(2026, 10, 1, 23), DateTime(2026, 10, 2, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 1, 23, 59)), 0);
    });
  });

  group('HomeRepository helpers', () {
    test('bestWeeklyCount ignores the current week and finds the busiest earlier one', () {
      final now = DateTime(2026, 10, 7);
      final dates = [
        DateTime(2026, 10, 6), // this week - excluded
        DateTime(2026, 9, 29), DateTime(2026, 9, 30), DateTime(2026, 10, 1), // last week: 3
        DateTime(2026, 9, 22), // the week before: 1
      ];
      expect(HomeRepository.bestWeeklyCount(dates, excludingWeekOf: now), 3);
    });

    test('motivation praises a best WEEK, not a streak', () {
      final msg = HomeRepository.motivation(1, 0, [DateTime(2026, 10, 6)]);
      expect(msg, contains('best week'));
      expect(msg, isNot(contains('streak yet')));
    });
  });
}
