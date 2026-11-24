import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_manifest.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_package_builder.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_verifier.dart';

import 'export_test_support.dart';

void main() {
  const builder = ExportPackageBuilder(byteHasher);
  const verifier = ExportPackageVerifier(byteHasher);
  final source = ExportSource(
    appVersion: '1.0.0',
    schemaVersion: 13,
    createdAtUtc: DateTime.utc(2026, 7, 1, 9),
  );
  const audit = ManifestAudit(chainStatus: 'intact', eventsChecked: 3, checkpointSequence: 3, checkpointHash: 'abc');
  final request = ExportRequest(
    period: ExportPeriod.financialYear(2025),
    datasets: {ExportDataset.products, ExportDataset.salesInvoices},
    format: ExportFormat.zip,
  );

  ExportPackage build({String root = 'Inventrix_Audit_Export'}) => builder.build(
    source: source,
    request: request,
    outputs: [
      DatasetOutput(dataset: ExportDataset.products, tables: sampleData()[ExportDataset.products]!),
      DatasetOutput(
        dataset: ExportDataset.salesInvoices,
        tables: sampleData()[ExportDataset.salesInvoices]!,
        files: {'documents/invoice_pdfs/INV-1.pdf': bytes('%PDF')},
      ),
    ],
    audit: audit,
    notes: const ['One attachment was missing.'],
    rootFolder: root,
  );

  test('the package has the files, manifest and checksum list', () {
    final p = build();
    expect(p.files.keys, containsAll([
      'Inventrix_Audit_Export/master_data/products.csv',
      'Inventrix_Audit_Export/sales/sales_invoices.csv',
      'Inventrix_Audit_Export/sales/sales_invoice_items.csv',
      'Inventrix_Audit_Export/documents/invoice_pdfs/INV-1.pdf',
      'Inventrix_Audit_Export/manifest.json',
      'Inventrix_Audit_Export/checksums/SHA256SUMS',
    ]));
  });

  test('the manifest records source, period, datasets, audit and caveats', () {
    final json = jsonDecode(
      utf8.decode(build().files['Inventrix_Audit_Export/manifest.json']!),
    ) as Map<String, Object?>;
    expect(json['appVersion'], '1.0.0');
    expect(json['schemaVersion'], 13);
    expect(json['createdAtUtc'], '2026-07-01T09:00:00.000Z');
    expect((json['period']! as Map)['label'], 'FY 2025-26');
    expect((json['period']! as Map)['from'], '2025-04-01');
    expect((json['period']! as Map)['to'], '2026-03-31');
    final datasets = (json['datasets']! as List).cast<Map<String, Object?>>();
    expect(datasets.map((d) => d['code']), ['products', 'sales_invoices']);
    expect(datasets.first['rowCount'], 2);
    expect(datasets.first['periodApplied'], false);
    expect(datasets.last['periodApplied'], true);
    expect((json['audit']! as Map)['chainStatus'], 'intact');
    expect((json['audit']! as Map)['checkpointHash'], 'abc');
    expect((json['notes']! as List).join(' '), contains('One attachment was missing.'));
    expect((json['integrity']! as Map)['signature'], isNull);
    expect(((json['integrity']! as Map)['signatureNote']! as String), contains('not prove who'));
  });

  test('every file is listed with its real SHA-256', () {
    final p = build();
    final json = jsonDecode(
      utf8.decode(p.files['Inventrix_Audit_Export/manifest.json']!),
    ) as Map<String, Object?>;
    final listed = (json['files']! as List).cast<Map<String, Object?>>();
    expect(listed, hasLength(p.files.length - 2));
    for (final f in listed) {
      expect(f['sha256'], byteHasher.sha256Hex(p.files[f['path']]!));
      expect(f['sizeBytes'], p.files[f['path']]!.length);
    }
  });

  test('SHA256SUMS lists every file but itself, in the sha256sum format', () {
    final p = build();
    final lines = utf8
        .decode(p.files['Inventrix_Audit_Export/checksums/SHA256SUMS']!)
        .trim()
        .split('\n');
    expect(lines, hasLength(p.files.length - 1));
    for (final line in lines) {
      expect(line, matches(RegExp(r'^[0-9a-f]{64}  \S+$')));
    }
    expect(lines.any((l) => l.endsWith('  Inventrix_Audit_Export/manifest.json')), isTrue);
    expect(lines.any((l) => l.contains('SHA256SUMS')), isFalse);
  });

  test('building twice gives identical bytes (deterministic)', () {
    final a = build();
    final b = build();
    for (final path in a.files.keys) {
      expect(a.files[path], b.files[path], reason: path);
    }
  });

  test('an untouched package verifies', () {
    final v = verifier.verify(build().files);
    expect(v.problems, isEmpty);
    expect(v.isValid, isTrue);
    expect(v.filesChecked, greaterThan(4));
  });

  test('a package without a root folder verifies too', () {
    expect(verifier.verify(build(root: '').files).isValid, isTrue);
  });

  group('tampering is detected', () {
    test('a changed file', () {
      final files = Map.of(build().files);
      files['Inventrix_Audit_Export/sales/sales_invoices.csv'] = bytes('id,total\r\ni1,1\r\n');
      final v = verifier.verify(files);
      expect(v.isValid, isFalse);
      expect(v.problems.join('\n'), contains('Changed file: Inventrix_Audit_Export/sales/sales_invoices.csv'));
    });

    test('a removed file', () {
      final files = Map.of(build().files)..remove('Inventrix_Audit_Export/master_data/products.csv');
      expect(verifier.verify(files).problems.join('\n'), contains('Missing file'));
    });

    test('an added file', () {
      final files = Map.of(build().files)..['Inventrix_Audit_Export/extra.txt'] = bytes('x');
      expect(verifier.verify(files).problems.join('\n'), contains('not in the checksum list'));
    });

    test('a rewritten checksum list does not hide a change from the manifest', () {
      final files = Map.of(build().files);
      const path = 'Inventrix_Audit_Export/master_data/products.csv';
      files[path] = bytes('forged');
      final sums = StringBuffer();
      for (final entry in (files.keys.toList()..sort())) {
        if (entry.endsWith('SHA256SUMS')) {
          continue;
        }
        sums.write('${byteHasher.sha256Hex(files[entry]!)}  $entry\n');
      }
      files['Inventrix_Audit_Export/checksums/SHA256SUMS'] = bytes(sums.toString());
      final v = verifier.verify(files);
      expect(v.isValid, isFalse);
      expect(v.problems.join('\n'), contains('Manifest hash differs'));
    });

    test('a missing manifest or checksum list', () {
      expect(
        verifier.verify(Map.of(build().files)..remove('Inventrix_Audit_Export/manifest.json')).isValid,
        isFalse,
      );
      expect(
        verifier.verify(Map.of(build().files)..remove('Inventrix_Audit_Export/checksums/SHA256SUMS')).isValid,
        isFalse,
      );
    });

    test('an unsafe path', () {
      final files = Map<String, Uint8List>.of(build().files)..['../evil.txt'] = bytes('x');
      expect(verifier.verify(files).problems.join('\n'), contains('Unsafe file path'));
    });

    test('a malformed checksum line', () {
      final files = Map.of(build().files);
      files['Inventrix_Audit_Export/checksums/SHA256SUMS'] = bytes('not a checksum line\n');
      expect(verifier.verify(files).problems.join('\n'), contains('Malformed checksum line'));
    });
  });

  test('an empty dataset still produces a CSV with its header', () {
    final p = builder.build(
      source: source,
      request: request,
      outputs: [DatasetOutput(dataset: ExportDataset.stockMovements, tables: sampleData()[ExportDataset.stockMovements]!)],
      audit: audit,
    );
    expect(
      utf8.decode(p.files['inventory/stock_movements.csv']!).replaceFirst('\uFEFF', ''),
      'id,quantity_delta_milli\r\n',
    );
    expect(p.manifest.datasets.single.rowCount, 0);
  });
}
