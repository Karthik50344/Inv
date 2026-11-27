import 'package:inventrix/core/security/database_key.dart';

/// Why the database could not be unlocked or opened securely.
enum DatabaseSecurityProblem {
  /// The platform secure storage could not be read or written.
  keyStorageUnavailable,

  /// An encrypted database exists but its key is gone.
  keyMissing,

  /// The stored key is damaged (wrong length or characters).
  keyInvalid,

  /// The key does not open the database file.
  unlockFailed,

  /// The loaded SQLite library is not SQLCipher: encryption would silently
  /// do nothing, so the app refuses to run.
  engineNotEncrypted,

  /// Encrypting the existing database failed; the old data was kept.
  migrationFailed,

  /// The database file is not a SQLite or SQLCipher database at all.
  unrecognizedFile,
}

/// A security-related failure while opening the database. Never deletes or
/// resets anything; the user message says what to do next.
final class DatabaseSecurityException implements Exception {
  /// Creates the exception.
  const DatabaseSecurityException(this.problem, this.message, {this.cause});

  /// Category.
  final DatabaseSecurityProblem problem;

  /// User-safe explanation.
  final String message;

  /// Underlying error, for logs only.
  final Object? cause;

  @override
  String toString() => 'DatabaseSecurityException($problem): $message';
}

/// Names of the secrets the app keeps.
abstract final class SecretNames {
  /// Key of the live database.
  static const String databaseKey = 'inventrix.database_key.v1';

  /// Key that lets this installation open its own backups.
  static const String backupDeviceKey = 'inventrix.backup_device_key.v1';
}

/// Platform-backed storage for [SecretKey256]s (Android Keystore / iOS
/// Keychain in production).
abstract interface class SecretStore {
  /// Raw stored text for [name], or `null` if nothing is stored.
  ///
  /// Throws [DatabaseSecurityException] (`keyStorageUnavailable`) if the
  /// storage cannot be read. It must never reset or delete on error.
  Future<String?> read(String name);

  /// Stores [value] under [name].
  Future<void> write(String name, String value);
}

/// Reads and creates keys with the safety rules of the app.
final class SecretKeyManager {
  /// Creates the manager.
  const SecretKeyManager(this._store);

  final SecretStore _store;

  /// Returns the stored key for [name]; `null` if none is stored. A stored
  /// but damaged value throws `keyInvalid` instead of being replaced.
  Future<SecretKey256?> readExisting(String name) async {
    final text = await _store.read(name);
    if (text == null) {
      return null;
    }
    final key = SecretKey256.tryParseHex(text.trim());
    if (key == null) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.keyInvalid,
        'The stored encryption key is damaged. Your data has not been '
        'changed. Restore a backup or contact support before reinstalling.',
      );
    }
    return key;
  }

  /// Creates, stores and returns a new key, then reads it back to prove it
  /// was really persisted. Only call when nothing depends on an older key.
  Future<SecretKey256> createNew(String name) async {
    final key = SecretKey256.generate();
    await _store.write(name, key.toHex());
    final back = await readExisting(name);
    if (back == null || !back.sameAs(key)) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.keyStorageUnavailable,
        'The secure storage of this device did not keep the new '
        'encryption key, so no data was created.',
      );
    }
    return key;
  }
}
