import 'dart:convert';
import 'dart:typed_data';

import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';

/// Encodes an [ExportTable] as RFC 4180 CSV (UTF-8 with a byte-order mark so
/// spreadsheet programs read non-English text correctly).
///
/// Numbers are written as they are. Text that starts with `=`, `+`, `-`,
/// `@`, a tab or a carriage return gets a leading apostrophe, so a customer
/// or product name can never run as a spreadsheet formula when an auditor
/// opens the file.
abstract final class CsvEncoder {
  static const List<int> _bom = [0xEF, 0xBB, 0xBF];

  /// The CSV bytes of [table].
  static Uint8List encode(ExportTable table, {bool withBom = true}) {
    final buffer = StringBuffer()
      ..write(_line(table.headers.map((h) => _cell(h, guard: false))));
    for (final row in table.rows) {
      buffer.write(_line(row.map((c) => _cell(c, guard: c is String))));
    }
    final body = utf8.encode(buffer.toString());
    return Uint8List.fromList([if (withBom) ..._bom, ...body]);
  }

  static String _line(Iterable<String> cells) => '${cells.join(',')}\r\n';

  static String _cell(Object? value, {required bool guard}) {
    if (value == null) {
      return '';
    }
    var text = value.toString();
    if (guard && text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
      text = "'$text";
    }
    final needsQuotes =
        text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
  }
}
