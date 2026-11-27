import 'dart:io';
import 'dart:typed_data';

import 'package:inventrix/core/database/database_session.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:logging/logging.dart';

/// SQL-level operations on database files (implemented with SQLCipher).
abstract interface class SqlcipherGateway {
  /// Whether the loaded SQLite library is really SQLCipher. A plain SQLite
  /// build ignores `PRAGMA key` and would create an unencrypted file.
  Future<bool> engineIsSqlcipher();

  /// Opens [path] with [key] and reads it; throws a
  /// [DatabaseSecurityException] (`unlockFailed`) if that does not work.
  Future<void> verifyUnlocks(String path, SecretKey256 key);

  /// Writes an encrypted copy of the plaintext database [plainPath] to the
  /// new file [targetPath] (all tables, indexes, triggers, views and the
  /// schema version) and verifies the copy. [plainPath] is not modified.
  Future<void> encryptCopy({
    required String plainPath,
    required String targetPath,
    required SecretKey256 key,
  });
}

/// How the database file on disk looks.
enum DatabaseFileFormat {
  /// No file, or an empty one.
  absent,

  /// Starts with the SQLite magic string: not encrypted.
  plaintext,

  /// Anything else (an encrypted database, or garbage).
  opaque,
}

/// Opens the live database securely: creates it encrypted, migrates an
/// existing plaintext database exactly once, and refuses to guess when a key
/// is missing or wrong.
///
/// Safety rules:
/// * A new key is generated only when no encrypted data depends on an older
///   one (no database, or a plaintext one being migrated).
/// * The plaintext original is deleted only after the encrypted copy has been
///   moved into place and opened successfully.
/// * Every interrupted step is recognised from the files on disk at the next
///   start and finished or undone without deleting data that is not provably
///   duplicated.
final class EncryptedDatabaseOpener {
  /// Creates the opener for the database at [path].
  EncryptedDatabaseOpener({
    required this.path,
    required SecretKeyManager keys,
    required SqlcipherGateway gateway,
  }) : _keys = keys,
       _gateway = gateway;

  /// Live database file.
  final String path;
  final SecretKeyManager _keys;
  final SqlcipherGateway _gateway;
  final Logger _log = Logger('EncryptedDatabaseOpener');

  static const List<String> _suffixes = ['', '-wal', '-shm', '-journal'];
  static const List<int> _sqliteMagic = [
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, //
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
  ];

  String get _encrypting => '$path.encrypting';
  String get _plainOld => '$path.plaintext-old';

  /// Prepares the database and returns the session to open it with.
  Future<DatabaseSession> open() async {
    if (!await _gateway.engineIsSqlcipher()) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.engineNotEncrypted,
        'This build of the app does not include database encryption, so it '
        'was stopped to protect your data. Please reinstall the latest '
        'official version without clearing its data.',
      );
    }
    await Directory(File(path).parent.path).create(recursive: true);
    await _recoverInterruptedMigration();

    switch (await formatOf(path)) {
      case DatabaseFileFormat.absent:
        final key =
            await _keys.readExisting(SecretNames.databaseKey) ??
            await _keys.createNew(SecretNames.databaseKey);
        return DatabaseSession(path: path, key: key);
      case DatabaseFileFormat.plaintext:
        return _migratePlaintext();
      case DatabaseFileFormat.opaque:
        final key = await _keys.readExisting(SecretNames.databaseKey);
        if (key == null) {
          throw const DatabaseSecurityException(
            DatabaseSecurityProblem.keyMissing,
            'The encryption key of this database is not available on this '
            'device (for example after restoring the phone from a cloud '
            'backup or clearing secure storage). Nothing was deleted or '
            'reset. Restore one of your exported backups with its recovery '
            'passphrase, or contact support before reinstalling.',
          );
        }
        await _gateway.verifyUnlocks(path, key);
        return DatabaseSession(path: path, key: key);
    }
  }

  /// After the app has opened the database: proves the file on disk is not
  /// plaintext (catches a misconfigured SQLite build that ignores keys).
  Future<void> assertEncryptedOnDisk() async {
    if (await formatOf(path) == DatabaseFileFormat.plaintext) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.engineNotEncrypted,
        'The database file is not encrypted. The app was stopped to protect '
        'your data.',
      );
    }
  }

  /// Reads the first bytes of [file] to classify it.
  static Future<DatabaseFileFormat> formatOf(String file) async {
    final f = File(file);
    if (!await f.exists() || await f.length() == 0) {
      return DatabaseFileFormat.absent;
    }
    final raf = await f.open();
    try {
      final head = await raf.read(_sqliteMagic.length);
      if (head.length == _sqliteMagic.length) {
        var same = true;
        for (var i = 0; i < head.length; i++) {
          if (head[i] != _sqliteMagic[i]) {
            same = false;
            break;
          }
        }
        if (same) {
          return DatabaseFileFormat.plaintext;
        }
      }
      return DatabaseFileFormat.opaque;
    } finally {
      await raf.close();
    }
  }

  Future<DatabaseSession> _migratePlaintext() async {
    final key =
        await _keys.readExisting(SecretNames.databaseKey) ??
        await _keys.createNew(SecretNames.databaseKey);
    try {
      await _gateway.encryptCopy(
        plainPath: path,
        targetPath: _encrypting,
        key: key,
      );
      await _gateway.verifyUnlocks(_encrypting, key);
      // Swap: the plaintext file is kept aside until the new one has opened.
      await File(path).rename(_plainOld);
      await _deleteCompanions(path);
      await File(_encrypting).rename(path);
      await _gateway.verifyUnlocks(path, key);
    } on Object catch (error, stackTrace) {
      _log.severe('Encrypting the database failed', error, stackTrace);
      await _undoSwap();
      if (error is DatabaseSecurityException) {
        rethrow;
      }
      throw DatabaseSecurityException(
        DatabaseSecurityProblem.migrationFailed,
        'Your data could not be encrypted, so it was left exactly as it '
        'was. Free some storage space and restart the app.',
        cause: error,
      );
    }
    await _wipe(_plainOld);
    return DatabaseSession(path: path, key: key);
  }

  /// Puts the plaintext original back if the swap got only half-way.
  Future<void> _undoSwap() async {
    await _deleteAll(_encrypting);
    if (await File(_plainOld).exists()) {
      if (await File(path).exists()) {
        await File(path).delete();
      }
      await File(_plainOld).rename(path);
    }
  }

  /// Finishes or undoes a migration that was interrupted by a crash.
  Future<void> _recoverInterruptedMigration() async {
    await _deleteAll(_encrypting); // never complete; derived data only
    final old = File(_plainOld);
    if (!await old.exists()) {
      return;
    }
    if (!await File(path).exists()) {
      await old.rename(path); // crashed between the two renames
      return;
    }
    if (await formatOf(path) == DatabaseFileFormat.opaque) {
      final key = await _keys.readExisting(SecretNames.databaseKey);
      if (key != null) {
        try {
          await _gateway.verifyUnlocks(path, key);
          await _wipe(_plainOld); // migration had succeeded
          return;
        } on DatabaseSecurityException {
          // The new file is unusable; keep the original and retry later.
        }
      }
    }
    // Both exist but the new file is not proven good: keep the plaintext
    // original as the live file (the encrypted one is moved away, not lost).
    final spare = '$path.unverified';
    if (await File(spare).exists()) {
      await File(spare).delete();
    }
    await File(path).rename(spare);
    await old.rename(path);
    await _deleteAll(spare);
  }

  Future<void> _deleteCompanions(String file) async {
    for (final s in _suffixes.skip(1)) {
      final f = File('$file$s');
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  Future<void> _deleteAll(String file) async {
    for (final s in _suffixes) {
      final f = File('$file$s');
      if (await f.exists()) {
        await f.delete();
      }
    }
  }

  /// Overwrites with zeros, then deletes (best effort; flash storage may
  /// keep old blocks, see docs/security/database_encryption.md).
  Future<void> _wipe(String file) async {
    for (final s in _suffixes) {
      final f = File('$file$s');
      if (!await f.exists()) {
        continue;
      }
      try {
        final length = await f.length();
        final raf = await f.open(mode: FileMode.writeOnly);
        try {
          final zeros = Uint8List(64 * 1024);
          var left = length;
          while (left > 0) {
            final n = left < zeros.length ? left : zeros.length;
            await raf.writeFrom(zeros, 0, n);
            left -= n;
          }
          await raf.flush();
        } finally {
          await raf.close();
        }
      } on FileSystemException catch (error) {
        _log.warning('Could not overwrite ${f.path}', error);
      }
      await f.delete();
    }
  }
}
