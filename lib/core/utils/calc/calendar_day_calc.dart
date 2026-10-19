/// Day arithmetic on local calendar dates.
///
/// `Duration(days: n)` is exactly n * 24 hours, so adding or subtracting it
/// across a DST change (e.g. 2026-10-25 in Europe/Madrid, a 25-hour day)
/// lands on 23:00 or 01:00 instead of midnight, and `difference().inDays`
/// between two local midnights comes out one short across a 23-hour day.
/// Midnight-keyed lookups (daily intake maps, trend series) then miss or
/// mis-assign days. These helpers count calendar days instead.
class CalendarDayCalc {
  /// Local midnight of the calendar day [days] days after [day] (negative
  /// goes back). The time-of-day component of [day] is dropped.
  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  /// Number of calendar days from [from] to [to], ignoring time of day and
  /// DST. Negative when [to] is before [from].
  static int daysBetween(DateTime from, DateTime to) {
    final fromUtc = DateTime.utc(from.year, from.month, from.day);
    final toUtc = DateTime.utc(to.year, to.month, to.day);
    return toUtc.difference(fromUtc).inDays;
  }
}
