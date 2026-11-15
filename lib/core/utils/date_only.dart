/// The calendar day of [value] as UTC midnight: the storage format for
/// document dates (an expense date, an invoice date, ...).
///
/// The year, month and day are taken as they are in [value]'s own time zone
/// (a date picked on screen keeps the day the user saw).
DateTime dateOnlyUtc(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
