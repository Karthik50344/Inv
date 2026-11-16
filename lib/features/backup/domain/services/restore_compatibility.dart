import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/entities/backup_manifest.dart';

/// Decides whether this version of the app can restore a backup.
abstract final class RestoreCompatibility {
  /// Returns a failure when [manifest] cannot be restored by an app whose
  /// database schema is [appSchemaVersion], otherwise `null`.
  ///
  /// Backups from **older** schemas are accepted: they are upgraded in the
  /// staging copy before anything live is touched.
  static Failure? check(
    BackupManifest manifest, {
    required int appSchemaVersion,
  }) {
    if (manifest.formatVersion > BackupFormat.formatVersion) {
      return const RestoreFailure(
        'This backup was made by a newer version of Inventrix. Update the '
        'app, then try again.',
      );
    }
    if (manifest.schemaVersion > appSchemaVersion) {
      return RestoreFailure(
        'This backup uses a newer data format (version '
        '${manifest.schemaVersion}) than this app understands (version '
        '$appSchemaVersion). Update the app, then try again.',
      );
    }
    return null;
  }
}
