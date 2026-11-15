import 'package:inventrix/shared/domain/value_objects/date_range.dart';

/// Date ranges offered on the dashboard and in reports.
enum ReportPeriod {
  /// Today only.
  today('Today'),

  /// The last 7 days including today.
  last7Days('Last 7 days'),

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

  const ReportPeriod(this.label);

  /// Label for the UI.
  final String label;

  /// The range of this period as seen from [today]; `null` for [custom].
  DateRange? rangeFor(DateTime today) {
    final t = DateTime.utc(today.year, today.month, today.day);
    switch (this) {
      case ReportPeriod.today:
        return DateRange(from: t, to: t);
      case ReportPeriod.last7Days:
        return DateRange(from: DateTime.utc(t.year, t.month, t.day - 6), to: t);
      case ReportPeriod.thisMonth:
        return DateRange(from: DateTime.utc(t.year, t.month), to: t);
      case ReportPeriod.lastMonth:
        return DateRange(
          from: DateTime.utc(t.year, t.month - 1),
          // Day 0 of a month is the last day of the previous one.
          to: DateTime.utc(t.year, t.month, 0),
        );
      case ReportPeriod.last30Days:
        return DateRange(
          from: DateTime.utc(t.year, t.month, t.day - 29),
          to: t,
        );
      case ReportPeriod.thisYear:
        return DateRange(from: DateTime.utc(t.year), to: t);
      case ReportPeriod.custom:
        return null;
    }
  }
}
