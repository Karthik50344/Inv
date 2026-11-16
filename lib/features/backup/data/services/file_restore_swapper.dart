import 'dart:io';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_swapper.dart';
import 'package:logging/logging.dart';

/// [RestoreSwapper] that works with plain files and renames.
///
/// Live files are **renamed** to `<name>.pre_restore`, never deleted, until
/// [commit]. Every step is undone by [rollBack], which can also be run after
/// a crash because it only looks at what is on disk.
final class FileRestoreSwapper implements RestoreSwapper {
  /// Creates the swapper.
  FileRestoreSwapper();

  final Logger _log = Logger('FileRestoreSwapper');

  @override
  Future<Result<void>> swapIn({
    required StagedBackup staged,
    required RestoreTargets targets,
  }) async {
    try {
      if (await _anyAside(targets)) {
        return const Result.failure(
          RestoreFailure(
            'An earlier restore has not finished cleaning up. Restart the '
            'app and try again.',
          ),
        );
      }
      if (!await File(staged.databasePath).exists()) {
        return const Result.failure(
          RestoreFailure('The staged database is missing.'),
        );
      }
      // Database files first; folders only after the database is aside, so a
      // crash can never leave folders swapped without a database aside.
      for (final suffix in RestoreTargets.databaseSuffixes) {
        final live = File('${targets.databasePath}$suffix');
        if (await live.exists()) {
          await live.rename('${live.path}${RestoreTargets.asideSuffix}');
        }
      }
      await _move(staged.databasePath, targets.databasePath);

      for (final folder in targets.dataFolders) {
        final live = Directory(folder.directoryPath);
        final aside = Directory(
          '${folder.directoryPath}${RestoreTargets.asideSuffix}',
        );
        if (await live.exists()) {
          await live.rename(aside.path);
        } else {
          await aside.create(recursive: true); // marker: nothing was there
        }
        final stagedPath = staged.dataFolders[folder.zipName];
        if (stagedPath != null && await Directory(stagedPath).exists()) {
          await _move(stagedPath, folder.directoryPath);
        }
      }
      return const Result.success(null);
    } on Object catch (error, stackTrace) {
      _log.severe('Swap failed, rolling back', error, stackTrace);
      final undone = await rollBack(targets);
      return Result.failure(
        RestoreFailure(
          undone.isSuccess
              ? 'The files could not be replaced; nothing was changed.'
              : 'The files could not be replaced and the previous files '
                    'could not be put back automatically.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> rollBack(RestoreTargets targets) async {
    try {
      final mainAside = File(
        '${targets.databasePath}${RestoreTargets.asideSuffix}',
      );
      if (await mainAside.exists()) {
        for (final suffix in RestoreTargets.databaseSuffixes) {
          final live = File('${targets.databasePath}$suffix');
          if (await live.exists()) {
            await live.delete();
          }
        }
        for (final suffix in RestoreTargets.databaseSuffixes) {
          final aside = File(
            '${targets.databasePath}$suffix${RestoreTargets.asideSuffix}',
          );
          if (await aside.exists()) {
            await aside.rename('${targets.databasePath}$suffix');
          }
        }
      }
      for (final folder in targets.dataFolders) {
        final aside = Directory(
          '${folder.directoryPath}${RestoreTargets.asideSuffix}',
        );
        if (!await aside.exists()) {
          continue;
        }
        final live = Directory(folder.directoryPath);
        if (await live.exists()) {
          await live.delete(recursive: true);
        }
        await aside.rename(folder.directoryPath);
      }
      return const Result.success(null);
    } on Object catch (error, stackTrace) {
      _log.severe('Rollback failed', error, stackTrace);
      return Result.failure(
        RestoreFailure(
          'The previous files could not be put back.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<void> commit(RestoreTargets targets) async {
    for (final suffix in RestoreTargets.databaseSuffixes) {
      await _deleteQuietly(
        File('${targets.databasePath}$suffix${RestoreTargets.asideSuffix}'),
      );
    }
    for (final folder in targets.dataFolders) {
      await _deleteQuietly(
        Directory('${folder.directoryPath}${RestoreTargets.asideSuffix}'),
      );
    }
  }

  Future<bool> _anyAside(RestoreTargets targets) async {
    for (final suffix in RestoreTargets.databaseSuffixes) {
      if (await File(
        '${targets.databasePath}$suffix${RestoreTargets.asideSuffix}',
      ).exists()) {
        return true;
      }
    }
    for (final folder in targets.dataFolders) {
      if (await Directory(
        '${folder.directoryPath}${RestoreTargets.asideSuffix}',
      ).exists()) {
        return true;
      }
    }
    return false;
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      _log.warning('Could not delete ${entity.path}', error);
    }
  }

  /// Renames; falls back to copy + delete when source and target are on
  /// different volumes.
  Future<void> _move(String from, String to) async {
    final type = await FileSystemEntity.type(from);
    try {
      if (type == FileSystemEntityType.directory) {
        await Directory(from).rename(to);
      } else {
        await File(from).rename(to);
      }
    } on FileSystemException {
      if (type == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(from), Directory(to));
        await Directory(from).delete(recursive: true);
      } else {
        await File(from).copy(to);
        await File(from).delete();
      }
    }
  }

  Future<void> _copyDirectory(Directory from, Directory to) async {
    await to.create(recursive: true);
    await for (final entity in from.list(recursive: true)) {
      final relative = entity.path.substring(from.path.length + 1);
      final target = '${to.path}${Platform.pathSeparator}$relative';
      if (entity is Directory) {
        await Directory(target).create(recursive: true);
      } else if (entity is File) {
        await Directory(File(target).parent.path).create(recursive: true);
        await entity.copy(target);
      }
    }
  }
}
