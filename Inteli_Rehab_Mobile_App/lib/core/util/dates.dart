/// Supabase returns timestamptz as an ISO string with a UTC offset
/// ("...+00:00"), which `DateTime.parse` turns into a UTC DateTime. Day,
/// week and streak maths must use the patient's own calendar, so every
/// timestamp read from the server goes through this.
DateTime parseTimestamp(String iso) => DateTime.parse(iso).toLocal();

/// Midnight (local) of [d]'s calendar day.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday 00:00 (local) of the week containing [d]. Built from calendar
/// fields, not by subtracting 24-hour Durations, which lands an hour off
/// across a daylight-saving change.
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Whole calendar days from [from] to [to] (DST-proof).
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Consecutive days, ending today (or yesterday if nothing is logged yet
/// today), with at least one session.
int currentStreak(Iterable<DateTime> dates, {DateTime? now}) {
  final days = dates.map(dayOf).toSet();
  final today = dayOf(now ?? DateTime.now());
  var cursor = days.contains(today) ? today : DateTime(today.year, today.month, today.day - 1);
  var streak = 0;
  while (days.contains(cursor)) {
    streak += 1;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}
