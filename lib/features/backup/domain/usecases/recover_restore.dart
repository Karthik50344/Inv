import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/entities/restore_notice.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_history_repository.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_journal_store.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_swapper.dart';

/// Runs at app start, **before the database is opened**: if the previous
/// run died in the middle of a restore, the old data is put back.
final class RecoverInterruptedRestore {
  /// Creates the use case.
  const RecoverInterruptedRestore({
    required RestoreJournalStore journal,
    required RestoreSwapper swapper,
  }) : _journal = journal,
       _swapper = swapper;

  final RestoreJournalStore _journal;
  final RestoreSwapper _swapper;

  /// Rolls back an interrupted restore. Returns `true` when it did.
  Future<bool> call() async {
    final entry = await _journal.read();
    if (entry == null || entry.state != RestoreJournalState.swapping) {
      return false;
    }
    final rolledBack = await _swapper.rollBack(entry.targets);
    if (rolledBack.isFailure) {
      // Keep the journal so that the next start tries again.
      return false;
    }
    await _journal.write(
      entry.copyWith(
        state: RestoreJournalState.rolledBack,
        failureMessage:
            'The restore was interrupted, so your previous data was put '
            'back.',
      ),
    );
    return true;
  }
}

/// Runs at app start, **after the database is open**: copies what the
/// restore journal knows into the backup history (the database that held
/// the old history may just have been replaced) and removes the journal.
final class ReconcileRestoreJournal {
  /// Creates the use case.
  const ReconcileRestoreJournal({
    required RestoreJournalStore journal,
    required BackupHistoryRepository history,
    required RestoreSwapper swapper,
    required String appVersion,
  }) : _journal = journal,
       _history = history,
       _swapper = swapper,
       _appVersion = appVersion;

  final RestoreJournalStore _journal;
  final BackupHistoryRepository _history;
  final RestoreSwapper _swapper;
  final String _appVersion;

  /// Returns a notice to show, or `null` when there was nothing to report.
  Future<RestoreNotice?> call() async {
    final entry = await _journal.read();
    if (entry == null || entry.state == RestoreJournalState.swapping) {
      return null;
    }
    final succeeded = entry.state == RestoreJournalState.completed;
    final records = [
      entry.safetyBackup,
      BackupRecord(
        id: entry.id,
        kind: BackupKind.restore,
        fileName: entry.sourceName,
        sizeBytes: 0,
        schemaVersion: entry.restoredSchemaVersion,
        appVersion: _appVersion,
        outcome: succeeded ? BackupOutcome.success : BackupOutcome.failed,
        errorMessage: succeeded ? null : entry.failureMessage,
        createdAt: entry.startedAt,
      ),
    ];
    for (final record in records) {
      final saved = await _history.add(record);
      if (saved.isFailure) {
        // Keep the journal; the next start retries.
        return null;
      }
    }
    if (succeeded) {
      // Idempotent: removes leftovers if the commit step was interrupted.
      await _swapper.commit(entry.targets);
    }
    await _journal.clear();
    return RestoreNotice(
      succeeded: succeeded,
      message: succeeded
          ? 'Backup restored. Your previous data was saved as '
                '${entry.safetyBackup.fileName}.'
          : (entry.failureMessage ??
                'The restore did not complete; your previous data is '
                    'unchanged.'),
    );
  }
}
