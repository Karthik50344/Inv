import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/database_inspection.dart';

/// Checks database files that are not the live database.
abstract interface class DatabaseInspector {
  /// Schema version this build of the app expects.
  int get appSchemaVersion;

  /// Opens [path] read-only and runs the integrity and foreign-key checks.
  Future<Result<DatabaseInspection>> inspect(String path);

  /// Opens [path] with the app's own schema (running any pending
  /// migrations, exactly as the app would), closes it, and inspects the
  /// result. Used on the staged copy so that a backup from an older version
  /// is upgraded and verified **before** anything live is replaced.
  Future<Result<DatabaseInspection>> migrateAndInspect(String path);
}
