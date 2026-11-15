import 'package:inventrix/shared/domain/value_objects/date_range.dart';

/// Small text helpers shared by the report builders.
abstract final class ReportText {
  /// `2026-11-01` for a date.
  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// `2026-11-01 to 2026-11-15`.
  static String period(DateRange range) =>
      '${isoDate(range.from)} to ${isoDate(range.to)}';

  /// Note about documents left out because of another currency, or
  /// `null` when there are none.
  static String? otherCurrencyNote(int count) => count == 0
      ? null
      : '$count record(s) in another currency are not included in the '
            'totals.';

  /// Note about a table that shows only the newest rows.
  static String truncationNote(int shown, int total) =>
      'Showing the newest $shown of $total rows. Narrow the dates to see '
      'the rest.';
}
