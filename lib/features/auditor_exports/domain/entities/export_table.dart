/// One table of an export: a file path inside the package, column names and
/// rows. Cells are `null`, `int`, `double` or `String`.
final class ExportTable {
  /// Creates a table.
  const ExportTable({
    required this.path,
    required this.headers,
    required this.rows,
  });

  /// Path inside the package, for example `sales/sales_invoices.csv`.
  final String path;

  /// Column names.
  final List<String> headers;

  /// Row values, one list per row, aligned with [headers].
  final List<List<Object?>> rows;

  /// A short sheet name derived from [path] (Excel allows 31 characters).
  String get sheetName {
    final base = path.split('/').last.replaceAll('.csv', '');
    final cleaned = base.replaceAll(RegExp(r'[\[\]:*?/\\]'), '_');
    return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
  }
}
