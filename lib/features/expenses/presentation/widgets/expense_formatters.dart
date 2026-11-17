import 'package:inventrix/core/formatters/date_formatter.dart';

/// Formats a stored (UTC, date-only) expense date for display in the style
/// chosen in the settings.
String formatExpenseDate(DateTime date) => DateFormatter.date(date);

/// Formats a file size such as `842 KB` or `1.4 MB` (display only).
String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${bytes ~/ 1024} KB';
  }
  final tenths = bytes * 10 ~/ (1024 * 1024);
  return '${tenths ~/ 10}.${tenths % 10} MB';
}

/// A share of [part] in [whole] as a percentage with one decimal, computed
/// with integers (`1234`, `10000` -> `12.3%`). Returns `0.0%` when [whole]
/// is not positive.
String formatShare(int part, int whole) {
  if (whole <= 0 || part <= 0) {
    return '0.0%';
  }
  final tenths = (part * 1000 + whole ~/ 2) ~/ whole;
  return '${tenths ~/ 10}.${tenths % 10}%';
}
