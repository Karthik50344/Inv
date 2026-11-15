import 'package:equatable/equatable.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';

/// One bar of a time chart: the days from [from] to [to], inclusive.
final class TimeBucket extends Equatable {
  /// Creates a bucket.
  const TimeBucket({required this.label, required this.from, required this.to});

  /// Axis label.
  final String label;

  /// First day.
  final DateTime from;

  /// Last day.
  final DateTime to;

  /// Whether [day] falls into the bucket.
  bool contains(DateTime day) => !day.isBefore(from) && !day.isAfter(to);

  @override
  List<Object?> get props => [label, from, to];
}

/// Splits a date range into chart buckets and adds amounts into them.
///
/// Ranges of up to [maxDailyDays] days get one bucket per day, longer ones
/// one bucket per calendar month (the first and last month may be partial).
abstract final class TimeBuckets {
  /// The longest range that is still shown day by day.
  static const int maxDailyDays = 31;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// The buckets of [range], in order.
  static List<TimeBucket> build(DateRange range) {
    final buckets = <TimeBucket>[];
    if (range.dayCount <= maxDailyDays) {
      var day = range.from;
      while (!day.isAfter(range.to)) {
        buckets.add(
          TimeBucket(
            label: '${day.day} ${_months[day.month - 1]}',
            from: day,
            to: day,
          ),
        );
        day = DateTime.utc(day.year, day.month, day.day + 1);
      }
      return buckets;
    }
    var start = range.from;
    while (!start.isAfter(range.to)) {
      final monthEnd = DateTime.utc(start.year, start.month + 1, 0);
      final end = monthEnd.isAfter(range.to) ? range.to : monthEnd;
      final yy = (start.year % 100).toString().padLeft(2, '0');
      buckets.add(
        TimeBucket(
          label: '${_months[start.month - 1]} $yy',
          from: start,
          to: end,
        ),
      );
      start = DateTime.utc(start.year, start.month + 1);
    }
    return buckets;
  }

  /// Sums [entries] into [buckets] (minor units). Entries outside every
  /// bucket are ignored.
  static List<int> sum(List<TimeBucket> buckets, List<DatedAmount> entries) {
    final totals = List<int>.filled(buckets.length, 0);
    for (final entry in entries) {
      final day = DateTime.utc(
        entry.date.year,
        entry.date.month,
        entry.date.day,
      );
      for (var i = 0; i < buckets.length; i++) {
        if (buckets[i].contains(day)) {
          totals[i] += entry.amount.minorUnits;
          break;
        }
      }
    }
    return totals;
  }

  /// [gross] minus [returns], bucket by bucket.
  static List<int> net(List<TimeBucket> buckets, DailySeries series) {
    final gross = sum(buckets, series.documents);
    final returns = sum(buckets, series.returns);
    return [for (var i = 0; i < gross.length; i++) gross[i] - returns[i]];
  }

  /// Running total of [values]: `[1, 2, -1]` becomes `[1, 3, 2]`.
  static List<int> cumulative(List<int> values) {
    final out = <int>[];
    var running = 0;
    for (final v in values) {
      running += v;
      out.add(running);
    }
    return out;
  }
}
