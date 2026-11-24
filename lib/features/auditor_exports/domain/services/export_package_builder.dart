import 'dart:convert';
import 'dart:typed_data';

import 'package:inventrix/features/auditor_exports/domain/entities/export_manifest.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';
import 'package:inventrix/features/auditor_exports/domain/services/byte_hasher.dart';
import 'package:inventrix/features/auditor_exports/domain/services/csv_encoder.dart';

/// The tables and loose files that make up one dataset.
final class DatasetOutput {
  /// Creates an output.
  const DatasetOutput({
    required this.dataset,
    this.tables = const [],
    this.files = const {},
  });

  /// Which dataset.
  final ExportDataset dataset;

  /// Tables, written as CSV.
  final List<ExportTable> tables;

  /// Other files by package path (PDFs, attachments).
  final Map<String, Uint8List> files;

  /// Rows over all tables.
  int get rowCount => tables.fold(0, (sum, t) => sum + t.rows.length);
}

/// A finished package ready to be zipped.
final class ExportPackage {
  /// Creates a package.
  const ExportPackage({required this.files, required this.manifest});

  /// Every file by path, including `manifest.json` and
  /// `checksums/SHA256SUMS`.
  final Map<String, Uint8List> files;

  /// The manifest that was written.
  final ExportManifest manifest;
}

/// Turns dataset outputs into a package: CSV files, manifest and checksums.
/// Pure and deterministic.
final class ExportPackageBuilder {
  /// Creates a builder.
  const ExportPackageBuilder(this._hasher);

  /// Path of the manifest.
  static const String manifestPath = 'manifest.json';

  /// Path of the checksum list.
  static const String checksumsPath = 'checksums/SHA256SUMS';

  final ByteHasher _hasher;

  /// Builds the package.
  ExportPackage build({
    required ExportSource source,
    required ExportRequest request,
    required List<DatasetOutput> outputs,
    required ManifestAudit audit,
    List<String> notes = const [],
    String rootFolder = '',
  }) {
    String at(String path) => rootFolder.isEmpty ? path : '$rootFolder/$path';

    final files = <String, Uint8List>{};
    final datasets = <ManifestDataset>[];
    for (final output in outputs) {
      final paths = <String>[];
      for (final table in output.tables) {
        final path = at(table.path);
        files[path] = CsvEncoder.encode(table);
        paths.add(path);
      }
      for (final entry in output.files.entries) {
        final path = at(entry.key);
        files[path] = entry.value;
        paths.add(path);
      }
      datasets.add(
        ManifestDataset(
          code: output.dataset.code,
          files: List.unmodifiable(paths..sort()),
          rowCount: output.rowCount,
          periodApplied: output.dataset.usesPeriod,
        ),
      );
    }

    final entries = [
      for (final e in files.entries)
        ManifestFile(
          path: e.key,
          sha256: _hasher.sha256Hex(e.value),
          sizeBytes: e.value.length,
        ),
    ]..sort((a, b) => a.path.compareTo(b.path));

    final manifest = ExportManifest(
      source: source,
      period: request.period,
      format: request.format,
      datasets: List.unmodifiable(datasets),
      files: List.unmodifiable(entries),
      audit: audit,
      notes: List.unmodifiable([
        'Amounts are in minor currency units (for example paise or cents); '
            'see the decimal_places column of each document.',
        'Dates are UTC. Master data, tax configuration and inventory '
            'balances are exported as they were at the export time; only '
            'datasets marked periodApplied are filtered by the period.',
        ...notes,
      ]),
    );
    final manifestBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest.toJson())),
    );
    files[at(manifestPath)] = manifestBytes;

    final sums = StringBuffer();
    final sorted = files.keys.toList()..sort();
    for (final path in sorted) {
      sums.write('${_hasher.sha256Hex(files[path]!)}  $path\n');
    }
    files[at(checksumsPath)] = Uint8List.fromList(utf8.encode(sums.toString()));

    return ExportPackage(files: files, manifest: manifest);
  }
}
