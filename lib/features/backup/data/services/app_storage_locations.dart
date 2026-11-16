import 'dart:io';

import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/services/backup_naming.dart';
import 'package:path/path.dart' as p;

/// [BackupLocations] on the device's file system.
final class AppStorageLocations implements BackupLocations {
  /// Creates the locations. [documents] and [temporary] are the platform
  /// folders (injectable for tests); [databasePath] resolves the live
  /// database file.
  AppStorageLocations({
    required Future<Directory> Function() documents,
    required Future<Directory> Function() temporary,
    required Future<String> Function() databasePath,
  }) : _documents = documents,
       _temporary = temporary,
       _databasePath = databasePath;

  static const String _backupsFolder = 'backups';
  static const String _stagingFolder = 'restore_staging';
  static const String _scratchPrefix = 'inventrix_';

  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _temporary;
  final Future<String> Function() _databasePath;

  @override
  Future<String> backupsDirectory() async {
    final directory = Directory(
      p.join((await _documents()).path, _backupsFolder),
    );
    await directory.create(recursive: true);
    return directory.path;
  }

  @override
  Future<String> resolveBackup(String storedPath) async {
    if (!BackupNaming.isPlainFileName(storedPath)) {
      throw ArgumentError.value(storedPath, 'storedPath', 'Not a file name');
    }
    return p.join(await backupsDirectory(), storedPath);
  }

  @override
  Future<bool> backupExists(String storedPath) async =>
      File(await resolveBackup(storedPath)).exists();

  @override
  Future<void> deleteBackup(String storedPath) async {
    final file = File(await resolveBackup(storedPath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String> createTempDirectory(String prefix) async {
    final directory = await (await _temporary()).createTemp(
      '$_scratchPrefix${prefix}_',
    );
    return directory.path;
  }

  @override
  Future<String> createStagingDirectory() async {
    final root = Directory(p.join((await _documents()).path, _stagingFolder));
    await root.create(recursive: true);
    return (await root.createTemp('restore_')).path;
  }

  @override
  Future<String> liveDatabasePath() => _databasePath();

  @override
  Future<List<BackupDataFolder>> dataFolders() async {
    final base = (await _documents()).path;
    return [
      BackupDataFolder(
        zipName: BackupDataFolders.receipts,
        directoryPath: p.join(base, 'attachments'),
      ),
      BackupDataFolder(
        zipName: BackupDataFolders.productImages,
        directoryPath: p.join(base, 'product_images'),
      ),
    ];
  }

  @override
  Future<void> discard(String path) async {
    final staging = p.join((await _documents()).path, _stagingFolder);
    final temp = (await _temporary()).path;
    final allowed =
        (p.isWithin(staging, path)) ||
        (p.isWithin(temp, path) && p.basename(path).startsWith(_scratchPrefix));
    if (!allowed) {
      return;
    }
    try {
      final directory = Directory(path);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // Scratch space; the OS cleans the temp folder eventually.
    }
  }
}
