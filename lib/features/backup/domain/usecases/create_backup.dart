import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_history_repository.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_key_provider.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';
import 'package:inventrix/features/backup/domain/repositories/database_inspector.dart';
import 'package:inventrix/features/backup/domain/repositories/database_snapshotter.dart';
import 'package:inventrix/features/backup/domain/services/backup_naming.dart';
import 'package:path/path.dart' as p;

/// Creates a backup archive in the app's backups folder.
///
/// 1. Snapshot the live database with SQLite's own mechanism (never a raw
///    copy of a file that is in use).
/// 2. Refuse to package a snapshot that fails the integrity or foreign-key
///    check: a backup of a damaged database would give false comfort.
/// 3. Write the ZIP (database, attachments, manifest with SHA-256 checksums)
///    and seal it in the authenticated encryption container; the plaintext
///    ZIP never leaves the private scratch folder and is overwritten.
/// 4. Re-open the finished container and verify every checksum.
/// 5. Record the result (also failures) in the history.
final class CreateBackup {
  /// Creates the use case.
  const CreateBackup({
    required DatabaseSnapshotter snapshotter,
    required DatabaseInspector inspector,
    required BackupPackager packager,
    required BackupLocations locations,
    required BackupHistoryRepository history,
    required BackupKeyProvider keys,
    required IdGenerator ids,
    required Clock clock,
    required String appVersion,
  }) : _snapshotter = snapshotter,
       _inspector = inspector,
       _packager = packager,
       _locations = locations,
       _history = history,
       _keys = keys,
       _ids = ids,
       _clock = clock,
       _appVersion = appVersion;

  final DatabaseSnapshotter _snapshotter;
  final DatabaseInspector _inspector;
  final BackupPackager _packager;
  final BackupLocations _locations;
  final BackupHistoryRepository _history;
  final BackupKeyProvider _keys;
  final IdGenerator _ids;
  final Clock _clock;
  final String _appVersion;

  /// Shortest accepted recovery passphrase.
  static const int minPassphraseLength = 10;

  /// Creates a backup of [kind] (`backup`, or `safety` before a restore).
  ///
  /// With a [recoveryPassphrase] the backup can also be opened on another
  /// device or after a reinstall; without one only this installation can
  /// open it.
  Future<Result<BackupRecord>> call({
    BackupKind kind = BackupKind.backup,
    String? recoveryPassphrase,
  }) async {
    if (kind == BackupKind.restore) {
      return const Result.failure(
        ValidationFailure('A restore is not a backup.'),
      );
    }
    if (recoveryPassphrase != null &&
        recoveryPassphrase.isNotEmpty &&
        recoveryPassphrase.length < minPassphraseLength) {
      return const Result.failure(
        ValidationFailure(
          'The recovery passphrase must have at least $minPassphraseLength '
          'characters.',
        ),
      );
    }
    final createdAt = _clock.now();
    String? work;
    String? storedName;
    try {
      work = await _locations.createTempDirectory('backup');
      final snapshotPath = p.join(work, 'snapshot.sqlite');
      final snapshot = await _snapshotter.snapshotTo(snapshotPath);
      if (snapshot case Err<void>(:final failure)) {
        return await _fail(kind, createdAt, failure);
      }

      final inspection = await _inspector.inspect(
        snapshotPath,
        key: _keys.databaseKey,
      );
      if (inspection case Err<dynamic>(:final failure)) {
        return await _fail(kind, createdAt, failure);
      }
      final health = inspection.valueOrNull!;
      if (!health.isHealthy) {
        return await _fail(
          kind,
          createdAt,
          BackupFailure(
            'The backup was not created because ${health.problem}. Your '
            'data has not been changed. Restart the app and try again; if '
            'it keeps failing, contact support before reinstalling.',
          ),
        );
      }

      storedName = await _freeName(createdAt, kind);
      final backups = await _locations.backupsDirectory();
      final packed = await _packager.pack(
        PackRequest(
          databasePath: snapshotPath,
          dataFolders: await _locations.dataFolders(),
          outputPath: p.join(backups, storedName),
          createdAt: createdAt,
          appVersion: _appVersion,
          schemaVersion: health.schemaVersion,
          recoveryPassphrase: recoveryPassphrase,
        ),
      );
      if (packed case Err<PackedBackup>(:final failure)) {
        return await _fail(kind, createdAt, failure);
      }
      final archive = packed.valueOrNull!;

      final verified = await _packager.verify(archive.path);
      if (verified case Err<dynamic>(:final failure)) {
        await _locations.deleteBackup(storedName);
        return await _fail(
          kind,
          createdAt,
          BackupFailure(
            'The backup file could not be verified after it was written, so '
            'it was discarded. ${failure.userMessage}',
            cause: failure,
          ),
        );
      }

      final record = BackupRecord(
        id: _ids.newId(),
        kind: kind,
        fileName: storedName,
        storedPath: storedName,
        sizeBytes: archive.sizeBytes,
        sha256: archive.sha256,
        schemaVersion: health.schemaVersion,
        appVersion: _appVersion,
        outcome: BackupOutcome.success,
        createdAt: createdAt,
      );
      final saved = await _history.add(record);
      if (saved case Err<void>(:final failure)) {
        // The archive is valid and on disk; losing the history row must not
        // hide that from the user, but the caller should know.
        return Result.failure(
          BackupFailure(
            'The backup file was created ($storedName) but could not be '
            'added to the history.',
            cause: failure,
          ),
        );
      }
      return Result.success(record);
    } on Object catch (error, stackTrace) {
      if (storedName != null) {
        await _locations.deleteBackup(storedName);
      }
      return await _fail(
        kind,
        createdAt,
        BackupFailure(
          'Could not create the backup.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      if (work != null) {
        await _locations.discard(work);
      }
    }
  }

  Future<String> _freeName(DateTime at, BackupKind kind) async {
    final prefix = kind == BackupKind.safety
        ? 'inventrix_safety'
        : 'inventrix_backup';
    var name = BackupNaming.fileName(at, prefix: prefix);
    var counter = 2;
    while (await _locations.backupExists(name)) {
      name = BackupNaming.fileName(at, prefix: prefix, suffix: counter++);
    }
    return name;
  }

  Future<Result<BackupRecord>> _fail(
    BackupKind kind,
    DateTime at,
    Failure failure,
  ) async {
    // Best effort: the history is informative, never a reason to hide the
    // real error.
    try {
      await _history.add(
        BackupRecord(
          id: _ids.newId(),
          kind: kind,
          fileName: BackupNaming.fileName(at),
          sizeBytes: 0,
          schemaVersion: _inspector.appSchemaVersion,
          appVersion: _appVersion,
          outcome: BackupOutcome.failed,
          errorMessage: failure.userMessage,
          createdAt: at,
        ),
      );
    } on Object {
      // Ignored on purpose.
    }
    return Result.failure(failure);
  }
}
