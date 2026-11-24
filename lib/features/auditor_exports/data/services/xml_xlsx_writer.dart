import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';

/// Writes a minimal, standard XLSX workbook (Office Open XML) without any
/// spreadsheet package: text is stored as inline strings (never as
/// formulas), numbers as numbers, headers in bold. Excel's limit of
/// 1,048,576 rows per sheet is respected; a sheet that would exceed it ends
/// with a visible `TRUNCATED` row.
final class XmlXlsxWriter implements XlsxWriter {
  /// Creates the writer.
  const XmlXlsxWriter();

  static const int _maxRows = 1048576;

  @override
  Uint8List write(List<ExportTable> sheets) {
    final names = _uniqueNames(sheets);
    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes(sheets.length)))
      ..addFile(_file('_rels/.rels', _rootRels))
      ..addFile(_file('xl/workbook.xml', _workbook(names)))
      ..addFile(_file('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length)))
      ..addFile(_file('xl/styles.xml', _styles));
    for (var i = 0; i < sheets.length; i++) {
      archive.addFile(_file('xl/worksheets/sheet${i + 1}.xml', _sheet(sheets[i])));
    }
    final List<int>? encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  ArchiveFile _file(String name, String text) =>
      ArchiveFile.bytes(name, utf8.encode(text));

  List<String> _uniqueNames(List<ExportTable> sheets) {
    final used = <String>{};
    final result = <String>[];
    for (final sheet in sheets) {
      var name = sheet.sheetName.isEmpty ? 'Sheet' : sheet.sheetName;
      var n = 2;
      while (!used.add(name.toLowerCase())) {
        final suffix = '_$n';
        final base = sheet.sheetName.length + suffix.length > 31
            ? sheet.sheetName.substring(0, 31 - suffix.length)
            : sheet.sheetName;
        name = '$base$suffix';
        n++;
      }
      result.add(name);
    }
    return result;
  }

  static const String _header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

  String _contentTypes(int count) =>
      '$_header<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '${[for (var i = 1; i <= count; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
      '</Types>';

  static const String _rootRels =
      '$_header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  String _workbook(List<String> names) =>
      '$_header<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
      '${[for (var i = 0; i < names.length; i++) '<sheet name="${_escape(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
      '</sheets></workbook>';

  String _workbookRels(int count) =>
      '$_header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 1; i <= count; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
      '<Relationship Id="rId${count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static const String _styles =
      '$_header<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
      '</styleSheet>';

  String _sheet(ExportTable table) {
    final out = StringBuffer(
      '$_header<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    );
    var rowNumber = 1;
    out.write(_row(rowNumber++, table.headers, header: true));
    final capacity = _maxRows - 1;
    final take = table.rows.length > capacity ? capacity - 1 : table.rows.length;
    for (var i = 0; i < take; i++) {
      out.write(_row(rowNumber++, table.rows[i]));
    }
    if (table.rows.length > capacity) {
      out.write(
        _row(rowNumber, [
          'TRUNCATED: this sheet holds only the first $take of '
              '${table.rows.length} rows. Use the CSV export for all rows.',
        ]),
      );
    }
    out.write('</sheetData></worksheet>');
    return out.toString();
  }

  String _row(int number, List<Object?> cells, {bool header = false}) {
    final out = StringBuffer('<row r="$number">');
    for (var c = 0; c < cells.length; c++) {
      final value = cells[c];
      if (value == null) {
        continue;
      }
      final ref = '${_column(c)}$number';
      if (value is int || (value is double && value.isFinite)) {
        out.write('<c r="$ref"><v>$value</v></c>');
      } else {
        out.write(
          '<c r="$ref" t="inlineStr"${header ? ' s="1"' : ''}>'
          '<is><t xml:space="preserve">${_escape(value.toString())}</t></is></c>',
        );
      }
    }
    out.write('</row>');
    return out.toString();
  }

  /// Column letters: 0 -> A, 25 -> Z, 26 -> AA.
  static String _column(int index) {
    var n = index;
    var letters = '';
    do {
      letters = String.fromCharCode(65 + n % 26) + letters;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return letters;
  }

  static final RegExp _invalidXml = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\uFFFE\uFFFF]');

  static String _escape(String text) => text
      .replaceAll(_invalidXml, '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
