import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';

/// Stores the restore journal outside the database.
abstract interface class RestoreJournalStore {
  /// The stored entry, or `null` when there is none (or it is unreadable).
  Future<RestoreJournalEntry?> read();

  /// Writes [entry] durably (replacing any earlier one).
  Future<void> write(RestoreJournalEntry entry);

  /// Removes the journal.
  Future<void> clear();
}
