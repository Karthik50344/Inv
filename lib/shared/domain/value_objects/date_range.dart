import 'package:equatable/equatable.dart';

/// An inclusive range of calendar days, stored as UTC midnights (the same
/// format as document dates).
final class DateRange extends Equatable {
  /// Creates a range. [from] and [to] are normalised to date-only values;
  /// [to] must not be before [from].
  DateRange({required DateTime from, required DateTime to})
    : from = DateTime.utc(from.year, from.month, from.day),
      to = DateTime.utc(to.year, to.month, to.day) {
    if (this.to.isBefore(this.from)) {
      throw ArgumentError.value(to, 'to', 'The range ends before it starts.');
    }
  }

  /// First day (inclusive).
  final DateTime from;

  /// Last day (inclusive).
  final DateTime to;

  /// Number of calendar days in the range.
  int get dayCount => to.difference(from).inDays + 1;

  /// Whether [day] (date part only) lies inside the range.
  bool contains(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    return !d.isBefore(from) && !d.isAfter(to);
  }

  @override
  List<Object?> get props => [from, to];

  @override
  String toString() => 'DateRange(${_iso(from)}..${_iso(to)})';

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
