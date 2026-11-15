import 'package:intl/intl.dart';

/// Formats a stored (UTC, date-only) document date for display.
String formatDocumentDate(DateTime date) =>
    DateFormat('d MMM yyyy').format(date);
