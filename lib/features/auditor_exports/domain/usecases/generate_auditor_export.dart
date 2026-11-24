import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_manifest.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_report.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/auditor_exports/domain/services/byte_hasher.dart';
import 'package:inventrix/features/auditor_exports/domain/services/csv_encoder.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_package_builder.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_verifier.dart';

/// Creates an auditor export.
///
/// Reading is done inside one read-only transaction, so every dataset comes
/// from the same consistent state, and nothing in the business data is
/// changed. The result is written to the app's exports folder, read back and
/// verified, recorded in the export history, and noted in the audit trail.
final class GenerateAuditorExport {
  /// Creates the use case.
  const GenerateAuditorExport({
    required ExportDataSource source,
    required ExportAssetReader assets,
    required ByteHasher hasher,
    required XlsxWriter xlsx,
    required ExportPdfWriter pdf,
    required ExportZipCodec zip,
    required ExportFileStore store,
    required ExportHistoryRepository history,
    required VerifyAuditChain verifyChain,
    required CreateAuditCheckpoint checkpoint,
    required AuditRecorder recorder,
    required Clock clock,
    required IdGenerator ids,
    required String appVersion,
  }) : _source = source,
       _assets = assets,
       _hasher = hasher,
       _xlsx = xlsx,
       _pdf = pdf,
       _zip = zip,
       _store = store,
       _history = history,
       _verifyChain = verifyChain,
       _checkpoint = checkpoint,
       _recorder = recorder,
       _clock = clock,
       _ids = ids,
       _appVersion = appVersion;

  /// Folder name inside the ZIP package.
  static const String rootFolder = 'Inventrix_Audit_Export';

  final ExportDataSource _source;
  final ExportAssetReader _assets;
  final ByteHasher _hasher;
  final XlsxWriter _xlsx;
  final ExportPdfWriter _pdf;
  final ExportZipCodec _zip;
  final ExportFileStore _store;
  final ExportHistoryRepository _history;
  final VerifyAuditChain _verifyChain;
  final CreateAuditCheckpoint _checkpoint;
  final AuditRecorder _recorder;
  final Clock _clock;
  final IdGenerator _ids;
  final String _appVersion;

  /// Runs the export.
  Future<Result<ExportRecord>> call(ExportRequest request) async {
    if (request.datasets.isEmpty) {
      return const Result.failure(
        ValidationFailure('Choose at least one thing to export.'),
      );
    }
    if (!request.period.isValid) {
      return const Result.failure(
        ValidationFailure('The start date must not be after the end date.'),
      );
    }
    final createdAt = _clock.now().toUtc();

    final gathered = await _source.inSnapshot<_Gathered>(
      (snapshot) => _gather(snapshot, request, createdAt),
    );
    final data = gathered.valueOrNull;
    if (data == null) {
      return Result.failure(gathered.failureOrNull!);
    }

    final built = await _render(request, data);
    final output = built.valueOrNull;
    if (output == null) {
      return Result.failure(built.failureOrNull!);
    }

    final id = _ids.newId();
    final name = (request.name?.trim().isNotEmpty ?? false)
        ? request.name!.trim()
        : 'Audit export ${request.period.label}';
    final fileName = _fileName(request, createdAt, id, isPackage: output.isPackage);
    try {
      await _store.write(fileName, output.bytes);
    } on Object catch (error, stack) {
      return Result.failure(
        ExportFailure(
          'The export file could not be saved. Check the free space on the '
          'device.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }

    // Read the saved file back and verify what is on disk, not what was
    // meant to be written.
    final saved = await _store.read(fileName);
    var status = 'failed';
    if (saved != null) {
      if (_hasher.sha256Hex(saved) != _hasher.sha256Hex(output.bytes)) {
        status = 'failed';
      } else if (output.isPackage) {
        final files = _zip.decode(saved).valueOrNull;
        status = files != null && ExportPackageVerifier(_hasher).verify(files).isValid
            ? 'verified'
            : 'failed';
      } else {
        status = 'verified';
      }
    }
    if (status != 'verified') {
      await _store.delete(fileName);
      return const Result.failure(
        ExportFailure(
          'The export file could not be verified after it was saved, so it '
          'was discarded. Please try again.',
        ),
      );
    }

    final record = ExportRecord(
      id: id,
      name: name,
      createdAt: createdAt,
      period: request.period,
      format: request.format,
      datasets: request.orderedDatasets,
      fileName: fileName,
      sizeBytes: output.bytes.length,
      sha256: _hasher.sha256Hex(output.bytes),
      integrityStatus: status,
      chainStatus: data.audit.chainStatus,
      appVersion: _appVersion,
      schemaVersion: data.schemaVersion,
      verifiedAt: _clock.now().toUtc(),
    );
    final stored = await _history.add(record);
    if (stored.isFailure) {
      await _store.delete(fileName);
      return Result.failure(stored.failureOrNull!);
    }

    // The file already exists, so this cannot share a transaction with the
    // export itself: it is queued durably if the audit write fails.
    final audited = await _recorder.recordOrQueue(
      AuditEventDraft(
        eventType: 'data_export.created',
        entityType: 'data_export',
        entityId: id,
        action: 'created',
        metadata: {
          'name': name,
          'period': request.period.label,
          'format': request.format.code,
          'datasets': [for (final d in request.orderedDatasets) d.code],
          'fileName': fileName,
          'sizeBytes': output.bytes.length,
          'sha256': record.sha256,
          'auditChain': data.audit.chainStatus,
        },
      ),
    );
    if (audited.isFailure) {
      return Result.failure(audited.failureOrNull!);
    }
    return Result.success(record);
  }

  // ------------------------------------------------------------- gather

  Future<_Gathered> _gather(
    ExportSnapshot snapshot,
    ExportRequest request,
    DateTime createdAt,
  ) async {
    final outputs = <DatasetOutput>[];
    final notes = <String>[];
    final period = request.period;

    // The chain is always verified and a checkpoint always taken, so every
    // export states the state of the audit trail it was made from.
    final verification = (await _verifyChain()).valueOrNull;
    final checkpoint = (await _checkpoint()).valueOrNull;
    final audit = ManifestAudit(
      chainStatus: verification == null
          ? 'unknown'
          : checkpoint == null
          ? 'empty'
          : verification.isValid
          ? 'intact'
          : 'broken',
      eventsChecked: verification?.eventsChecked ?? 0,
      problem: verification == null || verification.isValid
          ? null
          : _describe(verification),
      checkpointSequence: checkpoint?.sequence,
      checkpointHash: checkpoint?.eventHash,
    );

    for (final dataset in request.orderedDatasets) {
      switch (dataset) {
        case ExportDataset.attachments:
          final files = <String, Uint8List>{};
          final index = <List<Object?>>[];
          for (final a in await snapshot.attachments(period)) {
            final bytes = await _assets.attachment(a.storedPath);
            final path =
                'documents/attachments/${a.ownerType}/${_safe(a.ownerId)}/'
                '${_safe(a.id)}_${_safe(a.fileName)}';
            final data = bytes.valueOrNull;
            if (data == null) {
              notes.add('Attachment ${a.fileName} could not be read and is not included.');
            } else {
              files[path] = data;
            }
            index.add([a.id, a.ownerType, a.ownerId, a.fileName, data == null ? null : path, data?.length]);
          }
          outputs.add(
            DatasetOutput(
              dataset: dataset,
              tables: [
                ExportTable(
                  path: 'documents/attachments_index.csv',
                  headers: const ['id', 'owner_type', 'owner_id', 'file_name', 'package_path', 'size_bytes'],
                  rows: index,
                ),
              ],
              files: files,
            ),
          );
        case ExportDataset.invoicePdfs:
          final files = <String, Uint8List>{};
          for (final ref in await snapshot.salesInvoices(period)) {
            final pdf = await _assets.invoicePdf(ref.id);
            final bytes = pdf.valueOrNull;
            if (bytes == null) {
              notes.add('The PDF of invoice ${ref.number} could not be created.');
            } else {
              files['documents/invoice_pdfs/${_safe(ref.number)}.pdf'] = bytes;
            }
          }
          outputs.add(DatasetOutput(dataset: dataset, files: files));
        case ExportDataset.businessProfile:
          final tables = await snapshot.tables(dataset, period);
          outputs.add(
            DatasetOutput(
              dataset: dataset,
              tables: tables,
              files: {
                'business_profile/business_profile.pdf':
                    await _pdf.businessProfile(tables.first),
              },
            ),
          );
        case ExportDataset.auditTrail:
          final tables = await snapshot.tables(dataset, period);
          outputs.add(
            DatasetOutput(
              dataset: dataset,
              tables: tables,
              files: {
                'audit/audit_integrity_report.pdf': await _pdf.integrity(
                  IntegrityReport(
                    generatedAtUtc: createdAt,
                    audit: audit,
                    appVersion: _appVersion,
                    schemaVersion: await snapshot.schemaVersion(),
                  ),
                ),
              },
            ),
          );
        default:
          outputs.add(
            DatasetOutput(
              dataset: dataset,
              tables: await snapshot.tables(dataset, period),
            ),
          );
      }
    }
    return _Gathered(
      outputs: outputs,
      audit: audit,
      notes: notes,
      schemaVersion: await snapshot.schemaVersion(),
      createdAt: createdAt,
    );
  }

  String _describe(AuditVerification v) => switch (v.problem) {
    AuditProblem.hashMismatch =>
      'Event ${v.problemSequence} was changed after it was recorded.',
    AuditProblem.brokenLink =>
      'An event is missing or inserted before event ${v.problemSequence}.',
    AuditProblem.outOfOrder => 'Events are out of order at ${v.problemSequence}.',
    AuditProblem.checkpointMissing => 'The retained checkpoint is not in the chain.',
    AuditProblem.none => '',
  };

  // ------------------------------------------------------------- render

  Future<Result<_Output>> _render(ExportRequest request, _Gathered data) async {
    final source = ExportSource(
      appVersion: _appVersion,
      schemaVersion: data.schemaVersion,
      createdAtUtc: data.createdAt,
    );
    final allTables = [for (final o in data.outputs) ...o.tables];
    try {
      switch (request.format) {
        case ExportFormat.zip:
          final package = ExportPackageBuilder(_hasher).build(
            source: source,
            request: request,
            outputs: data.outputs,
            audit: data.audit,
            notes: data.notes,
            rootFolder: rootFolder,
          );
          return Result.success(_Output(_zip.encode(package.files), isPackage: true));
        case ExportFormat.csv:
          if (allTables.length == 1 && data.outputs.every((o) => o.files.isEmpty)) {
            return Result.success(_Output(CsvEncoder.encode(allTables.single)));
          }
          final package = ExportPackageBuilder(_hasher).build(
            source: source,
            request: request,
            outputs: [
              for (final o in data.outputs)
                DatasetOutput(dataset: o.dataset, tables: o.tables),
            ],
            audit: data.audit,
            notes: data.notes,
            rootFolder: rootFolder,
          );
          return Result.success(_Output(_zip.encode(package.files), isPackage: true));
        case ExportFormat.xlsx:
          final manifest = _manifestSheet(request, data, source);
          return Result.success(_Output(_xlsx.write([manifest, ...allTables])));
        case ExportFormat.pdf:
          final package = ExportPackageBuilder(_hasher).build(
            source: source,
            request: request,
            outputs: [
              for (final o in data.outputs)
                DatasetOutput(dataset: o.dataset, tables: o.tables),
            ],
            audit: data.audit,
            notes: data.notes,
            rootFolder: rootFolder,
          );
          final small = allTables
              .where(
                (t) =>
                    t.path.contains('summaries') ||
                    t.path.contains('tax_configurations') ||
                    t.path.contains('business_profile'),
              )
              .toList();
          return Result.success(
            _Output(
              await _pdf.report(
                ExportReport(
                  title: 'Inventrix audit export: ${request.period.label}',
                  manifest: package.manifest,
                  highlights: small,
                ),
              ),
            ),
          );
      }
    } on Object catch (error, stack) {
      return Result.failure(
        ExportFailure(
          'The export could not be built.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  ExportTable _manifestSheet(
    ExportRequest request,
    _Gathered data,
    ExportSource source,
  ) => ExportTable(
    path: 'manifest.csv',
    headers: const ['item', 'value'],
    rows: [
      ['application', 'Inventrix'],
      ['app_version', source.appVersion],
      ['schema_version', source.schemaVersion],
      ['created_at_utc', source.createdAtUtc.toIso8601String()],
      ['period', request.period.label],
      ['period_from', request.period.fromText],
      ['period_to', request.period.toText],
      ['audit_chain', data.audit.chainStatus],
      ['audit_events_checked', data.audit.eventsChecked],
      ['audit_checkpoint_sequence', data.audit.checkpointSequence],
      ['audit_checkpoint_hash', data.audit.checkpointHash],
      ['signature', 'not signed'],
      for (final o in data.outputs)
        ['dataset_${o.dataset.code}_rows', o.rowCount],
      for (final n in data.notes) ['note', n],
    ],
  );

  String _fileName(
    ExportRequest request,
    DateTime at,
    String id, {
    required bool isPackage,
  }) {
    final stamp =
        '${at.year.toString().padLeft(4, '0')}'
        '${at.month.toString().padLeft(2, '0')}'
        '${at.day.toString().padLeft(2, '0')}_'
        '${at.hour.toString().padLeft(2, '0')}'
        '${at.minute.toString().padLeft(2, '0')}'
        '${at.second.toString().padLeft(2, '0')}';
    final short = id.replaceAll('-', '').padRight(6, '0').substring(0, 6);
    final extension = isPackage
        ? 'zip'
        : switch (request.format) {
            ExportFormat.xlsx => 'xlsx',
            ExportFormat.pdf => 'pdf',
            ExportFormat.csv || ExportFormat.zip => 'csv',
          };
    return 'Inventrix_Audit_Export_${stamp}_$short.$extension';
  }

  static String _safe(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? '_' : cleaned;
  }
}

final class _Gathered {
  const _Gathered({
    required this.outputs,
    required this.audit,
    required this.notes,
    required this.schemaVersion,
    required this.createdAt,
  });

  final List<DatasetOutput> outputs;
  final ManifestAudit audit;
  final List<String> notes;
  final int schemaVersion;
  final DateTime createdAt;
}

final class _Output {
  const _Output(this.bytes, {this.isPackage = false});

  final Uint8List bytes;
  final bool isPackage;
}
