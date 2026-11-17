import 'package:inventrix/core/formatters/date_formatter.dart';

/// Formats a stored (UTC, date-only) document date for display in the style
/// chosen in the settings.
String formatDocumentDate(DateTime date) => DateFormatter.date(date);
