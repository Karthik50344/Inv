import 'package:inventrix/core/constants/app_constants.dart';

/// Constants describing the backup archive layout (see
/// `docs/workflows/backup_restore.md`).
abstract final class BackupFormat {
  /// Value of `application` in every manifest.
  static const String application = 'inventrix';

  /// Layout version written by this app. Restoring a backup with a higher
  /// version is refused.
  static const int formatVersion = 1;

  /// Manifest entry name.
  static const String manifestPath = 'manifest.json';

  /// Database entry name.
  static const String databasePath =
      'database/${AppConstants.databaseName}.sqlite';

  /// Informational metadata entry name.
  static const String metadataInfoPath = 'metadata/backup_info.json';

  /// Prefix of every attachment entry.
  static const String attachmentsPrefix = 'attachments/';

  /// Prefix of metadata entries.
  static const String metadataPrefix = 'metadata/';

  /// Most entries a backup may contain (guards against archive bombs).
  static const int maxEntries = 50000;

  /// Most uncompressed bytes a backup may declare.
  static const int maxTotalBytes = 4 * 1024 * 1024 * 1024;

  /// Longest accepted entry name.
  static const int maxNameLength = 240;
}

/// A folder of user files that is part of the business data and therefore
/// part of every backup.
final class BackupDataFolder {
  /// Creates a data folder: [zipName] is its name below `attachments/` in
  /// the archive, [directoryPath] its location on this device.
  const BackupDataFolder({required this.zipName, required this.directoryPath});

  /// Name below `attachments/` in the archive.
  final String zipName;

  /// Absolute directory on the device.
  final String directoryPath;
}

/// Archive names of the folders the app knows how to restore.
abstract final class BackupDataFolders {
  /// Expense receipts (`<documents>/attachments`).
  static const String receipts = 'receipts';

  /// Product photos (`<documents>/product_images`).
  static const String productImages = 'product_images';

  /// Every accepted folder name.
  static const Set<String> all = {receipts, productImages};
}
