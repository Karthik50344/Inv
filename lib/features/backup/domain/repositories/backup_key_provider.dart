import 'package:inventrix/core/security/database_key.dart';

/// Keys the backup feature needs.
abstract interface class BackupKeyProvider {
  /// Key that lets this installation open its own backups. Created on first
  /// use.
  Future<SecretKey256> deviceKey();

  /// Key of the live database, or `null` when the app runs on an in-memory
  /// test database.
  SecretKey256? get databaseKey;
}
