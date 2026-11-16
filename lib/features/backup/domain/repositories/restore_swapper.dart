import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';

/// Replaces the live files with a staged backup, and can undo that.
///
/// Callers must make sure the database is closed first.
abstract interface class RestoreSwapper {
  /// Moves the live files aside (never deletes them) and moves the staged
  /// files into place. If it fails part-way it puts everything back itself.
  Future<Result<void>> swapIn({
    required StagedBackup staged,
    required RestoreTargets targets,
  });

  /// Puts the files that were moved aside back and removes the restored
  /// ones. Safe to call repeatedly, and after a crash.
  Future<Result<void>> rollBack(RestoreTargets targets);

  /// Deletes the files that were moved aside, once the restored data has
  /// proven itself.
  Future<void> commit(RestoreTargets targets);
}
