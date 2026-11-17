import 'package:intl/intl.dart';
import 'package:inventrix/core/formatters/display_formats.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

/// Formats dates in the style chosen in the settings.
abstract final class DateFormatter {
  /// Formats a calendar date, e.g. `15 Nov 2026` or `15/11/2026`.
  ///
  /// Document dates are stored as UTC midnight of the chosen day, so they are
  /// formatted as they are; convert timestamps with `toLocal()` first.
  static String date(DateTime date, {DateStyle? style}) =>
      DateFormat((style ?? DisplayFormats.dateStyle).pattern).format(date);

  /// Formats a moment, e.g. `15 Nov 2026, 3:05 PM`. [moment] is converted to
  /// local time.
  static String dateTime(DateTime moment, {DateStyle? style}) =>
      DateFormat('${(style ?? DisplayFormats.dateStyle).pattern}, h:mm a')
          .format(moment.toLocal());
}
