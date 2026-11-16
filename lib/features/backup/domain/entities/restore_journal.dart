import 'package:equatable/equatable.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';

/// Where a restore writes to.
final class RestoreTargets extends Equatable {
  /// Creates targets.
  const RestoreTargets({required this.databasePath, required this.dataFolders});

  /// Suffix appended to live files while they wait to be deleted or put back.
  static const String asideSuffix = '.pre_restore';

  /// Companion files SQLite may keep next to the database.
  static const List<String> databaseSuffixes = ['', '-wal', '-shm', '-journal'];

  /// Live database file.
  final String databasePath;

  /// Live data folders.
  final List<BackupDataFolder> dataFolders;

  @override
  List<Object?> get props => [
    databasePath,
    dataFolders.map((f) => '${f.zipName}=${f.directoryPath}').toList(),
  ];
}

/// How far a restore got.
enum RestoreJournalState {
  /// Files are being swapped; an interruption must be rolled back.
  swapping('swapping'),

  /// The restored data is live; the history still has to be updated.
  completed('completed'),

  /// The old data was put back; the history still has to be updated.
  rolledBack('rolled_back');

  const RestoreJournalState(this.value);

  /// Stored value.
  final String value;

  /// Parses [value]; returns `null` if unknown.
  static RestoreJournalState? tryParse(String value) {
    for (final state in values) {
      if (state.value == value) {
        return state;
      }
    }
    return null;
  }
}

/// Crash-safe record of a restore, kept in a file next to the data because
/// the database itself is being replaced.
final class RestoreJournalEntry extends Equatable {
  /// Creates an entry.
  const RestoreJournalEntry({
    required this.id,
    required this.state,
    required this.startedAt,
    required this.sourceName,
    required this.restoredSchemaVersion,
    required this.targets,
    required this.safetyBackup,
    this.failureMessage,
  });

  /// Id used for the history row written afterwards.
  final String id;

  /// Progress.
  final RestoreJournalState state;

  /// When the restore began (UTC).
  final DateTime startedAt;

  /// Name of the backup file being restored.
  final String sourceName;

  /// Schema version of the backup.
  final int restoredSchemaVersion;

  /// Live locations.
  final RestoreTargets targets;

  /// The backup taken just before the swap.
  final BackupRecord safetyBackup;

  /// Why the restore was rolled back.
  final String? failureMessage;

  /// Copy with a new [state] (and [failureMessage]).
  RestoreJournalEntry copyWith({
    required RestoreJournalState state,
    String? failureMessage,
  }) => RestoreJournalEntry(
    id: id,
    state: state,
    startedAt: startedAt,
    sourceName: sourceName,
    restoredSchemaVersion: restoredSchemaVersion,
    targets: targets,
    safetyBackup: safetyBackup,
    failureMessage: failureMessage ?? this.failureMessage,
  );

  @override
  List<Object?> get props => [
    id,
    state,
    startedAt,
    sourceName,
    restoredSchemaVersion,
    targets,
    safetyBackup,
    failureMessage,
  ];
}

/// What a finished restore reports to the caller.
final class RestoreOutcome extends Equatable {
  /// Creates an outcome.
  const RestoreOutcome({
    required this.sourceName,
    required this.safetyBackup,
    required this.restoredSchemaVersion,
  });

  /// File that was restored.
  final String sourceName;

  /// Archive of the data that was replaced (kept so the restore can be
  /// undone).
  final BackupRecord safetyBackup;

  /// Schema version of the restored backup (before any upgrade).
  final int restoredSchemaVersion;

  @override
  List<Object?> get props => [sourceName, safetyBackup, restoredSchemaVersion];
}
