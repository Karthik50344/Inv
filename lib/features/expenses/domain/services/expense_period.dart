/// Date ranges offered in the expense report.
enum ExpensePeriod {
  /// The current calendar month up to today.
  thisMonth('This month'),

  /// The previous calendar month.
  lastMonth('Last month'),

  /// The last 30 days including today.
  last30Days('Last 30 days'),

  /// The current calendar year up to today.
  thisYear('This year'),

  /// A range chosen by the user.
  custom('Custom');

  const ExpensePeriod(this.label);

  /// Label for the UI.
  final String label;

  /// The inclusive date range of this period as seen from [today] (a UTC
  /// date-only value). `null` for [custom].
  ({DateTime from, DateTime to})? rangeFor(DateTime today) {
    switch (this) {
      case ExpensePeriod.thisMonth:
        return (from: DateTime.utc(today.year, today.month), to: today);
      case ExpensePeriod.lastMonth:
        final first = DateTime.utc(today.year, today.month - 1);
        // Day 0 of a month is the last day of the previous one.
        final last = DateTime.utc(today.year, today.month, 0);
        return (from: first, to: last);
      case ExpensePeriod.last30Days:
        return (
          from: DateTime.utc(today.year, today.month, today.day - 29),
          to: today,
        );
      case ExpensePeriod.thisYear:
        return (from: DateTime.utc(today.year), to: today);
      case ExpensePeriod.custom:
        return null;
    }
  }
}
