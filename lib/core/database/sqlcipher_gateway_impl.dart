import 'dart:io';
import 'dart:isolate';

import 'package:inventrix/core/database/encrypted_database_opener.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

/// [SqlcipherGateway] on top of `package:sqlite3` (linked to SQLCipher by
/// the `hooks: user_defines: sqlite3: source: sqlcipher` setting in
/// `pubspec.yaml`). Heavy work runs in a short-lived isolate.
final class Sqlite3SqlcipherGateway implements SqlcipherGateway {
  /// Creates the gateway.
  const Sqlite3SqlcipherGateway();

  @override
  Future<bool> engineIsSqlcipher() => Isolate.run(sqlcipherAvailable);

  @override
  Future<void> verifyUnlocks(String path, SecretKey256 key) {
    final hex = key.toHex();
    return Isolate.run(() => unlockCheck(path, hex));
  }

  @override
  Future<void> encryptCopy({
    required String plainPath,
    required String targetPath,
    required SecretKey256 key,
  }) {
    final hex = key.toHex();
    return Isolate.run(() => encryptPlaintextCopy(plainPath, targetPath, hex));
  }
}

/// Whether the loaded library reports a SQLCipher version.
bool sqlcipherAvailable() {
  final db = sqlite3.openInMemory();
  try {
    final rows = db.select('PRAGMA cipher_version');
    return rows.isNotEmpty &&
        (rows.first.values.first?.toString().isNotEmpty ?? false);
  } finally {
    db.close();
  }
}

/// Applies the raw key to an open connection and checks the library is
/// SQLCipher. Does not read the file.
void applyKey(CommonDatabase db, String hex) {
  db.execute('''PRAGMA key = "x'$hex'"''');
  final rows = db.select('PRAGMA cipher_version');
  if (rows.isEmpty || (rows.first.values.first?.toString().isEmpty ?? true)) {
    throw const DatabaseSecurityException(
      DatabaseSecurityProblem.engineNotEncrypted,
      'The SQLite library in this build does not support encryption.',
    );
  }
}

/// Opens [path] with the key and reads it (this fails for a wrong key).
void unlockCheck(String path, String hex) {
  final Database db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readWrite);
  } on SqliteException catch (error) {
    throw DatabaseSecurityException(
      DatabaseSecurityProblem.unlockFailed,
      'The database file could not be opened.',
      cause: error,
    );
  }
  try {
    applyKey(db, hex);
    db.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException catch (error) {
    throw DatabaseSecurityException(
      DatabaseSecurityProblem.unlockFailed,
      'The encryption key of this device does not open the database. '
      'Nothing was deleted or reset. Restore one of your exported backups '
      'with its recovery passphrase, or contact support before '
      'reinstalling.',
      cause: error,
    );
  } finally {
    db.close();
  }
}

String _sqlText(String value) => "'${value.replaceAll("'", "''")}'";

String _ident(String value) => '"${value.replaceAll('"', '""')}"';

/// Encrypted copy of a plaintext database (see [SqlcipherGateway]).
void encryptPlaintextCopy(String plainPath, String targetPath, String hex) {
  // Needs the create flag: ATTACH inherits the open flags of this connection
  // and must be able to create the new encrypted file. The source file
  // already exists, so nothing is created for it.
  if (!File(plainPath).existsSync()) {
    throw StateError('Database to encrypt does not exist: $plainPath');
  }
  final db = sqlite3.open(plainPath);
  try {
    final version = db.select('PRAGMA cipher_version');
    if (version.isEmpty) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.engineNotEncrypted,
        'The SQLite library in this build does not support encryption.',
      );
    }
    final userVersion = db.select('PRAGMA main.user_version').first.values
        .first! as int;
    final applicationId = db.select('PRAGMA main.application_id').first.values
        .first! as int;
    db.execute(
      'ATTACH DATABASE ${_sqlText(targetPath)} AS enc '
      "KEY ${_sqlText("x'$hex'")}",
    );
    db.select("SELECT sqlcipher_export('enc')");
    // sqlcipher_export does not copy these two header values; Drift's schema
    // version lives in user_version, so losing it would re-run migrations.
    db.execute('PRAGMA enc.user_version = $userVersion');
    db.execute('PRAGMA enc.application_id = $applicationId');
    final tables = db
        .select(
          "SELECT name FROM main.sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .map((r) => r['name']! as String)
        .toList();
    for (final table in tables) {
      final a =
          db.select('SELECT count(*) AS c FROM main.${_ident(table)}').first['c'];
      final b =
          db.select('SELECT count(*) AS c FROM enc.${_ident(table)}').first['c'];
      if (a != b) {
        throw StateError('Row count differs in $table: $a vs $b');
      }
    }
    final check = db
        .select('PRAGMA enc.integrity_check')
        .map((r) => r.values.first.toString())
        .toList();
    if (check.length != 1 || check.first != 'ok') {
      throw StateError('Encrypted copy failed its integrity check: $check');
    }
    db.execute('DETACH DATABASE enc');
  } finally {
    db.close();
  }
}

/// Re-encrypts [path] from [fromHex] to [toHex] in place (`PRAGMA rekey`).
void rekeyDatabase(String path, String fromHex, String toHex) {
  final db = sqlite3.open(path, mode: OpenMode.readWrite);
  try {
    applyKey(db, fromHex);
    db.select('SELECT count(*) FROM sqlite_master');
    db.execute('''PRAGMA rekey = "x'$toHex'"''');
  } finally {
    db.close();
  }
}
