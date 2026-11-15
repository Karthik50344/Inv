import 'package:inventrix/features/reports/domain/entities/report_document.dart';

/// Turns a [ReportDocument] into CSV text (RFC 4180: comma separated, CRLF
/// line ends, quotes doubled).
///
/// Numbers are written plainly (no currency symbol, no thousands
/// separators) so spreadsheets read them as numbers. Text that starts with
/// `=`, `+`, `-`, `@`, a tab or a carriage return is prefixed with an
/// apostrophe so a spreadsheet never runs it as a formula (CSV injection);
/// numeric cells are exempt because negative numbers legitimately start
/// with `-`.
abstract final class ReportCsv {
  /// Byte order mark that makes Excel read the file as UTF-8.
  static const String bom = '\uFEFF';

  /// Encodes [document]. With [withBom] the text starts with [bom].
  static String encode(ReportDocument document, {bool withBom = true}) {
    final out = StringBuffer();
    void line(List<String> fields) => out
      ..write(fields.join(','))
      ..write('\r\n');

    line([_text(document.title)]);
    if (document.periodText != null) {
      line([_text('Period'), _text(document.periodText!)]);
    }
    for (final scope in document.scope) {
      line([_text(scope)]);
    }
    line([_text('Generated'), _plain(_iso(document.generatedAt))]);

    if (document.metrics.isNotEmpty) {
      line(const []);
      line([_text('Summary')]);
      for (final metric in document.metrics) {
        line([_text(metric.label), cellText(metric.value)]);
      }
    }
    for (final table in document.tables) {
      line(const []);
      line([_text(table.title)]);
      line([for (final c in table.columns) _text(c.label)]);
      for (final row in table.rows) {
        line([for (final cell in row) cellText(cell)]);
      }
      if (table.isTruncated) {
        line([
          _text(
            'Only ${table.rows.length} of ${table.totalRowCount} rows '
            'are included.',
          ),
        ]);
      }
    }
    if (document.notes.isNotEmpty) {
      line(const []);
      line([_text('Notes')]);
      for (final note in document.notes) {
        line([_text(note)]);
      }
    }
    return withBom ? '$bom$out' : out.toString();
  }

  /// The CSV field for one cell.
  static String cellText(ReportCell cell) => switch (cell) {
    TextCell(:final text) => _text(text),
    MoneyCell(:final money) => _plain(money.toPlainString()),
    QuantityCell(:final quantity, :final decimals) => _plain(
      quantity.toFixedString(decimals),
    ),
    CountCell(:final count) => _plain(count.toString()),
    DateCell(:final date) => _plain(_isoDate(date)),
    PercentCell(:final basisPoints) => _plain(percentText(basisPoints)),
    EmptyCell() => '',
  };

  /// Basis points as a percentage with two decimals, e.g. `1234` ->
  /// `12.34`.
  static String percentText(int basisPoints) {
    final sign = basisPoints < 0 ? '-' : '';
    final abs = basisPoints.abs();
    final whole = abs ~/ 100;
    final fraction = (abs % 100).toString().padLeft(2, '0');
    return '$sign$whole.$fraction';
  }

  static String _plain(String value) => _quoteIfNeeded(value);

  static String _text(String value) {
    var safe = value;
    if (safe.isNotEmpty && '=+-@\t\r'.contains(safe[0])) {
      safe = "'$safe";
    }
    return _quoteIfNeeded(safe);
  }

  static String _quoteIfNeeded(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  static String _iso(DateTime value) => value.toUtc().toIso8601String();

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
