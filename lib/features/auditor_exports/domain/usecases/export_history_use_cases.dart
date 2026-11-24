import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/auditor_exports/domain/services/byte_hasher.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_verifier.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';

/// Lists past exports, newest first.
final class ListExportHistory {
  /// Creates the use case.
  const ListExportHistory(this._history);

  final ExportHistoryRepository _history;

  /// The records.
  Future<Result<List<ExportRecord>>> call({int limit = 100}) =>
      _history.list(limit: limit);
}

/// Checks a saved export again: the file must still exist, match the hash
/// recorded when it was made and, for a package, pass its own checksums.
final class VerifyExportFile {
  /// Creates the use case.
  const VerifyExportFile({
    required ExportHistoryRepository history,
    required ExportFileStore store,
    required ExportZipCodec zip,
    required ByteHasher hasher,
    required Clock clock,
  }) : _history = history,
       _store = store,
       _zip = zip,
       _hasher = hasher,
       _clock = clock;

  final ExportHistoryRepository _history;
  final ExportFileStore _store;
  final ExportZipCodec _zip;
  final ByteHasher _hasher;
  final Clock _clock;

  /// Re-verifies [id]; returns the new integrity status.
  Future<Result<String>> call(String id) async {
    final loaded = await _history.getById(id);
    final record = loaded.valueOrNull;
    if (record == null) {
      return Result.failure(
        loaded.failureOrNull ?? const NotFoundFailure('This export no longer exists.'),
      );
    }
    var status = 'failed';
    if (record.hasFile) {
      final bytes = await _store.read(record.fileName);
      if (bytes != null && _hasher.sha256Hex(bytes) == record.sha256) {
        status = 'verified';
        if (record.fileName.endsWith('.zip')) {
          final files = _zip.decode(bytes).valueOrNull;
          if (files == null || !ExportPackageVerifier(_hasher).verify(files).isValid) {
            status = 'failed';
          }
        }
      }
    }
    final saved = await _history.updateIntegrity(
      id,
      status: status,
      at: _clock.now().toUtc(),
    );
    return saved.isFailure ? Result.failure(saved.failureOrNull!) : Result.success(status);
  }
}

/// Shares or saves an export file with the system's own dialogs. Nothing is
/// uploaded anywhere automatically.
final class ShareExportFile {
  /// Creates the use case.
  const ShareExportFile({
    required ExportHistoryRepository history,
    required ExportFileStore store,
    required BackupExporter exporter,
    required AuditRecorder recorder,
  }) : _history = history,
       _store = store,
       _exporter = exporter,
       _recorder = recorder;

  final ExportHistoryRepository _history;
  final ExportFileStore _store;
  final BackupExporter _exporter;
  final AuditRecorder _recorder;

  /// Hands the file of export [id] to the share sheet or the save dialog.
  Future<Result<ExportResult>> call(String id, ExportMode mode) async {
    final loaded = await _history.getById(id);
    final record = loaded.valueOrNull;
    if (record == null || !record.hasFile) {
      return Result.failure(
        loaded.failureOrNull ??
            const NotFoundFailure('The export file is no longer on this device.'),
      );
    }
    final bytes = await _store.read(record.fileName);
    if (bytes == null) {
      return const Result.failure(
        NotFoundFailure('The export file is no longer on this device.'),
      );
    }
    final result = await _exporter.export(
      path: await _store.resolve(record.fileName),
      fileName: record.fileName,
      mode: mode,
    );
    final done = result.valueOrNull;
    if (done != null && done.completed) {
      await _recorder.recordOrQueue(
        AuditEventDraft(
          eventType: 'data_export.shared',
          entityType: 'data_export',
          entityId: id,
          action: mode == ExportMode.share ? 'shared' : 'saved_to_device',
          metadata: {'fileName': record.fileName, 'sha256': record.sha256},
        ),
      );
    }
    return result;
  }
}

/// Removes an export file from the device. The history record and its
/// audit events stay.
final class DeleteExportFile {
  /// Creates the use case.
  const DeleteExportFile({
    required ExportHistoryRepository history,
    required ExportFileStore store,
    required AuditRecorder recorder,
    required Clock clock,
  }) : _history = history,
       _store = store,
       _recorder = recorder,
       _clock = clock;

  final ExportHistoryRepository _history;
  final ExportFileStore _store;
  final AuditRecorder _recorder;
  final Clock _clock;

  /// Deletes the file of export [id].
  Future<Result<void>> call(String id) async {
    final loaded = await _history.getById(id);
    final record = loaded.valueOrNull;
    if (record == null) {
      return Result.failure(
        loaded.failureOrNull ?? const NotFoundFailure('This export no longer exists.'),
      );
    }
    if (!record.hasFile) {
      return const Result.success(null);
    }
    await _store.delete(record.fileName);
    final marked = await _history.markFileDeleted(id, _clock.now().toUtc());
    if (marked.isFailure) {
      return marked;
    }
    return _recorder.recordOrQueue(
      AuditEventDraft(
        eventType: 'data_export.file_deleted',
        entityType: 'data_export',
        entityId: id,
        action: 'file_deleted',
        metadata: {'fileName': record.fileName, 'format': record.format.code},
      ),
    );
  }
}
