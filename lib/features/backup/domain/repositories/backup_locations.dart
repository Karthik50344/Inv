import 'package:inventrix/features/backup/domain/entities/backup_format.dart';

/// Where backup-related files live on this device.
abstract interface class BackupLocations {
  /// Folder holding the app's own copies of backups (created on demand).
  Future<String> backupsDirectory();

  /// Absolute path of a stored backup, given the relative [storedPath] kept
  /// in the history. Throws [ArgumentError] when the name is not a plain file
  /// name, so a damaged history row can never point outside the folder.
  Future<String> resolveBackup(String storedPath);

  /// Whether a stored backup named [storedPath] exists.
  Future<bool> backupExists(String storedPath);

  /// Deletes the stored backup named [storedPath] (no error if it is gone).
  Future<void> deleteBackup(String storedPath);

  /// A new empty folder for scratch work (snapshots).
  Future<String> createTempDirectory(String prefix);

  /// A new empty folder for staging a restore, on the same storage as the
  /// live data so files can be renamed into place.
  Future<String> createStagingDirectory();

  /// Absolute path of the live database file. Only valid while the database
  /// is open.
  Future<String> liveDatabasePath();

  /// Folders of user files that belong to the business data.
  Future<List<BackupDataFolder>> dataFolders();

  /// Deletes a folder previously returned by [createTempDirectory] or
  /// [createStagingDirectory]. Refuses (silently) any other path.
  Future<void> discard(String path);
}
