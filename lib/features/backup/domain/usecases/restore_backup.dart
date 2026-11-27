import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/entities/database_inspection.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/features/backup/domain/repositories/app_runtime.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_key_provider.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/repositories/database_key_aligner.dart';
import 'package:inventrix/features/backup/domain/repositories/database_inspector.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_journal_store.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_swapper.dart';
import 'package:inventrix/features/backup/domain/services/restore_compatibility.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';

/// Replaces the current business data with a validated, staged backup.
///
/// The order is what keeps existing data safe:
///
/// 1. The caller must have confirmed (re-checked here, not just in the UI).
/// 2. The staged database is upgraded to the current schema and verified
///    **in the staging folder** - a backup that cannot be opened by this app
///    is refused while nothing live has been touched.
/// 3. A safety backup of the current data is created and verified. If that
///    fails the restore does not start.
/// 4. A journal file records the intent (the database is about to be
///    replaced, so it cannot hold this record itself).
/// 5. The app releases the database; the live files are **moved aside, never
///    deleted**, and the staged files moved in.
/// 6. The app starts again on the restored data. Any failure in steps 5-6
///    puts the old files back and starts the app on them.
/// 7. Only after the restored data opened successfully are the moved-aside
///    files deleted.
///
/// If the process dies between 4 and 7, [RecoverInterruptedRestore] puts the
/// old data back on the next start.
final class RestoreBackup {
  /// Creates the use case.
  const RestoreBackup({
    required DatabaseInspector inspector,
    required BackupLocations locations,
    required CreateBackup createBackup,
    required BackupKeyProvider keys,
    required DatabaseKeyAligner aligner,
    required RestoreSwapper swapper,
    required RestoreJournalStore journal,
    required AppRuntime runtime,
    required IdGenerator ids,
    required Clock clock,
  }) : _inspector = inspector,
       _locations = locations,
       _createBackup = createBackup,
       _keys = keys,
       _aligner = aligner,
       _swapper = swapper,
       _journal = journal,
       _runtime = runtime,
       _ids = ids,
       _clock = clock;

  final DatabaseInspector _inspector;
  final BackupLocations _locations;
  final CreateBackup _createBackup;
  final BackupKeyProvider _keys;
  final DatabaseKeyAligner _aligner;
  final RestoreSwapper _swapper;
  final RestoreJournalStore _journal;
  final AppRuntime _runtime;
  final IdGenerator _ids;
  final Clock _clock;

  /// Restores [staged]. [confirmed] must be `true`.
  Future<Result<RestoreOutcome>> call({
    required StagedBackup staged,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const Result.failure(
        ValidationFailure(
          'Confirm that you want to replace the current data with this '
          'backup.',
        ),
      );
    }
    final incompatible = RestoreCompatibility.check(
      staged.manifest,
      appSchemaVersion: _inspector.appSchemaVersion,
    );
    if (incompatible != null) {
      return Result.failure(incompatible);
    }

    try {
      // 2. Upgrade and verify the staged copy.
      final migrated = await _inspector.migrateAndInspect(
        staged.databasePath,
        key: staged.databaseKey,
      );
      if (migrated case Err<DatabaseInspection>(:final failure)) {
        return Result.failure(
          RestoreFailure(
            'This backup could not be opened by this version of the app, so '
            'nothing was changed. ${failure.userMessage}',
            cause: failure,
          ),
        );
      }
      final health = migrated.valueOrNull!;
      if (!health.isHealthy) {
        return Result.failure(
          RestoreFailure(
            'This backup failed its checks after being upgraded '
            '(${health.problem}), so nothing was changed.',
          ),
        );
      }

      // 2b. Make the staged database use THIS device's key, so the live
      // database keeps opening with the key in secure storage. It is
      // proven by opening the result with that key before anything live is
      // touched.
      final liveKey = _keys.databaseKey;
      if (liveKey != null) {
        final aligned = await _aligner.align(
          staged.databasePath,
          currentKey: staged.databaseKey,
          targetKey: liveKey,
        );
        if (aligned case Err<void>(:final failure)) {
          return Result.failure(failure);
        }
        final reopened = await _inspector.inspect(
          staged.databasePath,
          key: liveKey,
        );
        if (reopened case Err<DatabaseInspection>(:final failure)) {
          return Result.failure(failure);
        }
        if (!reopened.valueOrNull!.isHealthy) {
          return const Result.failure(
            RestoreFailure(
              'The backup failed its checks after being prepared for this '
              'device, so nothing was changed.',
            ),
          );
        }
      }

      // 3. Safety backup of what is about to be replaced.
      final targets = RestoreTargets(
        databasePath: await _locations.liveDatabasePath(),
        dataFolders: await _locations.dataFolders(),
      );
      final safety = await _createBackup(kind: BackupKind.safety);
      if (safety case Err<BackupRecord>(:final failure)) {
        return Result.failure(
          RestoreFailure(
            'Your current data could not be backed up first, so nothing was '
            'changed. ${failure.userMessage}',
            cause: failure,
          ),
        );
      }

      // 4. Journal.
      final entry = RestoreJournalEntry(
        id: _ids.newId(),
        state: RestoreJournalState.swapping,
        startedAt: _clock.now(),
        sourceName: staged.sourceName,
        restoredSchemaVersion: staged.manifest.schemaVersion,
        targets: targets,
        safetyBackup: safety.valueOrNull!,
      );
      await _journal.write(entry);

      // 5. Release the database.
      try {
        await _runtime.shutDown();
      } on Object catch (error, stackTrace) {
        await _startQuietly();
        await _journal.clear();
        return Result.failure(
          RestoreFailure(
            'The app could not pause to apply the backup, so nothing was '
            'changed.',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }

      // 5b. Swap files.
      final swapped = await _swapper.swapIn(staged: staged, targets: targets);
      if (swapped case Err<void>(:final failure)) {
        return await _abort(
          entry,
          RestoreFailure(
            'The backup could not be put in place. Your previous data was '
            'kept. ${failure.userMessage}',
            cause: failure,
          ),
          // swapIn already undid its own partial work; rolling back again
          // could mistake an unrelated leftover for ours.
          undoSwap: false,
        );
      }

      // 6. Start on the restored data.
      try {
        await _runtime.start();
      } on Object catch (error, stackTrace) {
        return await _abort(
          entry,
          RestoreFailure(
            'The app could not open the restored data, so your previous '
            'data was put back.',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }

      // 7. Commit. The journal moves to `completed` first: from then on an
      // interrupted run keeps the restored data instead of rolling back.
      try {
        await _journal.write(
          entry.copyWith(state: RestoreJournalState.completed),
        );
      } on Object catch (error, stackTrace) {
        return await _abort(
          entry,
          RestoreFailure(
            'The restore could not be recorded, so your previous data was '
            'put back.',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
      await _swapper.commit(targets);
      try {
        // Record it and show the "restored" message now, not at next launch.
        await _runtime.reportRestoreResult();
      } on Object {
        // Informative only; the journal stays and the next launch reports.
      }
      return Result.success(
        RestoreOutcome(
          sourceName: staged.sourceName,
          safetyBackup: entry.safetyBackup,
          restoredSchemaVersion: staged.manifest.schemaVersion,
        ),
      );
    } on Object catch (error, stackTrace) {
      return Result.failure(
        RestoreFailure(
          'The restore failed. If the app looks wrong, restart it: your '
          'previous data is recovered automatically.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      await _locations.discard(staged.directory);
    }
  }

  /// Puts the old files back, restarts on them and records the failure.
  Future<Result<RestoreOutcome>> _abort(
    RestoreJournalEntry entry,
    RestoreFailure reason, {
    bool undoSwap = true,
  }) async {
    final rolledBack = undoSwap
        ? await _swapper.rollBack(entry.targets)
        : const Result<void>.success(null);
    if (rolledBack case Err<void>(:final failure)) {
      // Leave the journal in `swapping`: the next app start retries.
      return Result.failure(
        RestoreFailure(
          '${reason.message} Your previous data could not be put back '
          'automatically; restart the app and it will be recovered. '
          '${failure.userMessage}',
          cause: reason.cause,
        ),
      );
    }
    await _journal.write(
      entry.copyWith(
        state: RestoreJournalState.rolledBack,
        failureMessage: reason.message,
      ),
    );
    try {
      await _runtime.start();
    } on Object catch (error, stackTrace) {
      return Result.failure(
        RestoreFailure(
          '${reason.message} The app could not be restarted; close and '
          'reopen it.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    return Result.failure(reason);
  }

  Future<void> _startQuietly() async {
    try {
      await _runtime.start();
    } on Object {
      // The caller reports the original problem.
    }
  }
}
