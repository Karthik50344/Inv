import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/auditor_exports/data/services/xml_xlsx_writer.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';
import 'package:inventrix/features/auditor_exports/domain/services/csv_encoder.dart';

String csv(ExportTable t) => utf8.decode(CsvEncoder.encode(t, withBom: false));

void main() {
  group('CSV', () {
    test('header, rows, CRLF line ends and a byte-order mark', () {
      final t = ExportTable(path: 'a.csv', headers: ['id', 'qty'], rows: [
        ['x', 1],
        ['y', 2],
      ]);
      expect(csv(t), 'id,qty\r\nx,1\r\ny,2\r\n');
      expect(CsvEncoder.encode(t).take(3), [0xEF, 0xBB, 0xBF]);
    });

    test('commas, quotes and line breaks are quoted', () {
      final t = ExportTable(path: 'a.csv', headers: ['n'], rows: [
        ['Smith, John'],
        ['say "hi"'],
        ['two\nlines'],
      ]);
      expect(csv(t), 'n\r\n"Smith, John"\r\n"say ""hi"""\r\n"two\nlines"\r\n');
    });

    test('null is empty and numbers stay numbers', () {
      final t = ExportTable(path: 'a.csv', headers: ['a', 'b', 'c'], rows: [
        [null, -5, 1.5],
      ]);
      expect(csv(t), 'a,b,c\r\n,-5,1.5\r\n');
    });

    test('text that could run as a formula is neutralised, numbers are not', () {
      final t = ExportTable(path: 'a.csv', headers: ['n'], rows: [
        ['=SUM(A1)'],
        ['+1'],
        ['-1'],
        ['@cmd'],
        [-1],
        ['normal'],
      ]);
      expect(csv(t), "n\r\n'=SUM(A1)\r\n'+1\r\n'-1\r\n'@cmd\r\n-1\r\nnormal\r\n");
    });

    test('an empty table still has its header', () {
      expect(csv(ExportTable(path: 'a.csv', headers: ['a', 'b'], rows: [])), 'a,b\r\n');
    });

    test('non-English text survives', () {
      final t = ExportTable(path: 'a.csv', headers: ['n'], rows: [['नमस्ते']]);
      expect(csv(t), 'n\r\nनमस्ते\r\n');
    });
  });

  group('period', () {
    test('an Indian financial year runs April to March', () {
      final p = ExportPeriod.financialYear(2025);
      expect(p.fromText, '2025-04-01');
      expect(p.toText, '2026-03-31');
      expect(p.label, 'FY 2025-26');
      expect(p.kind, ExportPeriodKind.financialYear);
    });

    test('a calendar year is a financial year starting in January', () {
      final p = ExportPeriod.financialYear(2026, startMonth: 1);
      expect(p.fromText, '2026-01-01');
      expect(p.toText, '2026-12-31');
      expect(p.label, 'Calendar year 2026');
    });

    test('the end date is inclusive down to the last millisecond', () {
      final p = ExportPeriod.custom(DateTime.utc(2026, 6, 1), DateTime.utc(2026, 6, 30, 15));
      expect(p.fromMs, DateTime.utc(2026, 6, 1).millisecondsSinceEpoch);
      expect(
        p.toMsInclusive,
        DateTime.utc(2026, 7, 1).millisecondsSinceEpoch - 1,
      );
    });

    test('all dates has no bounds', () {
      const p = ExportPeriod.all();
      expect(p.fromMs, isNull);
      expect(p.toMsInclusive, isNull);
      expect(p.isValid, isTrue);
    });

    test('a start after the end is invalid', () {
      expect(
        ExportPeriod.custom(DateTime.utc(2026, 7), DateTime.utc(2026, 6)).isValid,
        isFalse,
      );
    });
  });

  group('XLSX', () {
    Map<String, String> read(List<int> data) => {
      for (final f in ZipDecoder().decodeBytes(data).files)
        if (f.isFile) f.name: utf8.decode(f.readBytes()!),
    };

    test('has the parts of a valid workbook and one sheet per table', () {
      final bytes = const XmlXlsxWriter().write([
        ExportTable(path: 'a/one.csv', headers: ['id', 'n'], rows: [['x', 5]]),
        ExportTable(path: 'a/two.csv', headers: ['q'], rows: []),
      ]);
      final parts = read(bytes);
      expect(
        parts.keys,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/styles.xml',
          'xl/worksheets/sheet1.xml',
          'xl/worksheets/sheet2.xml',
        ]),
      );
      expect(parts['xl/workbook.xml'], contains('name="one"'));
      expect(parts['xl/workbook.xml'], contains('name="two"'));
      expect(parts['xl/worksheets/sheet1.xml'], contains('<c r="B2"><v>5</v></c>'));
      expect(parts['xl/worksheets/sheet1.xml'], contains('<t xml:space="preserve">x</t>'));
    });

    test('text is stored as text, never as a formula, and is escaped', () {
      final parts = read(
        const XmlXlsxWriter().write([
          ExportTable(path: 'a.csv', headers: ['n'], rows: [
            ['=1+1'],
            ['<b>&"</b>'],
          ]),
        ]),
      );
      final sheet = parts['xl/worksheets/sheet1.xml']!;
      expect(sheet, isNot(contains('<f>')));
      expect(sheet, contains('t="inlineStr"'));
      expect(sheet, contains('=1+1'));
      expect(sheet, contains('&lt;b&gt;&amp;&quot;&lt;/b&gt;'));
    });

    test('control characters that XML forbids are removed', () {
      final parts = read(
        const XmlXlsxWriter().write([
          ExportTable(path: 'a.csv', headers: ['n'], rows: [['a\x01b']]),
        ]),
      );
      expect(parts['xl/worksheets/sheet1.xml'], contains('>ab<'));
    });

    test('column letters continue past Z', () {
      final headers = [for (var i = 0; i < 28; i++) 'c$i'];
      final parts = read(
        const XmlXlsxWriter().write([ExportTable(path: 'a.csv', headers: headers, rows: [])]),
      );
      final sheet = parts['xl/worksheets/sheet1.xml']!;
      expect(sheet, contains('r="Z1"'));
      expect(sheet, contains('r="AA1"'));
      expect(sheet, contains('r="AB1"'));
    });

    test('sheets with the same name get unique names and long names are cut', () {
      final parts = read(
        const XmlXlsxWriter().write([
          ExportTable(path: 'x/same.csv', headers: ['a'], rows: []),
          ExportTable(path: 'y/same.csv', headers: ['a'], rows: []),
          ExportTable(path: 'z/${'long' * 20}.csv', headers: ['a'], rows: []),
        ]),
      );
      final wb = parts['xl/workbook.xml']!;
      expect(wb, contains('name="same"'));
      expect(wb, contains('name="same_2"'));
      final names = RegExp(r'name="([^"]+)"').allMatches(wb).map((m) => m.group(1)!);
      expect(names.every((n) => n.length <= 31), isTrue);
    });
  });
}
