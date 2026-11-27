import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/encrypted_database_opener.dart';
import 'package:inventrix/core/database/sqlcipher_gateway_impl.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Runs against the real SQLCipher library that `pubspec.yaml` bundles
/// (`hooks: user_defines: sqlite3: source: sqlcipher`).
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ivx_sqlcipher_');
    path = '${dir.path}/inventory_management.sqlite';
  });
  tearDown(() => dir.delete(recursive: true));

  void createPlain(String file) {
    final db = sqlite3.open(file);
    db.execute('''
      CREATE TABLE parent(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL);
      CREATE TABLE child(id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL REFERENCES parent(id), qty INTEGER);
      CREATE INDEX idx_child_parent ON child(parent_id);
      CREATE TABLE audit(n INTEGER);
      CREATE TRIGGER trg AFTER INSERT ON child BEGIN INSERT INTO audit VALUES (new.qty); END;
      CREATE VIEW v AS SELECT parent_id, SUM(qty) AS q FROM child GROUP BY parent_id;
      INSERT INTO parent(name) VALUES ('Secret Customer Ltd');
      INSERT INTO child(parent_id, qty) VALUES (1, 5), (1, 7);
      PRAGMA user_version = 13;
    ''');
    db.close();
  }

  bool isPlainHeader(String file) {
    final head = File(file).openSync().readSync(15);
    return String.fromCharCodes(head) == 'SQLite format 3';
  }

  Database openKeyed(String file, SecretKey256 key) {
    final db = sqlite3.open(file);
    applyKey(db, key.toHex());
    return db;
  }

  test('the bundled SQLite library is SQLCipher', () {
    expect(sqlcipherAvailable(), isTrue);
  });

  test('encrypted database: not plaintext, wrong or no key fails', () {
    final key = SecretKey256.generate();
    final db = openKeyed(path, key);
    db.execute("CREATE TABLE t(x TEXT); INSERT INTO t VALUES ('Secret Customer Ltd');");
    db.close();

    expect(isPlainHeader(path), isFalse);
    expect(
      String.fromCharCodes(File(path).readAsBytesSync()).contains('Secret Customer'),
      isFalse,
    );
    final again = openKeyed(path, key);
    expect(again.select('SELECT x FROM t').single['x'], 'Secret Customer Ltd');
    again.close();

    expect(() => unlockCheck(path, SecretKey256.generate().toHex()),
        throwsA(isA<DatabaseSecurityException>()));
    final noKey = sqlite3.open(path);
    expect(() => noKey.select('SELECT * FROM t'), throwsA(isA<SqliteException>()));
    noKey.close();
  });

  test('plaintext copy keeps data, schema objects and schema version', () {
    createPlain(path);
    final key = SecretKey256.generate();
    encryptPlaintextCopy(path, '$path.enc', key.toHex());

    expect(isPlainHeader('$path.enc'), isFalse);
    final db = openKeyed('$path.enc', key);
    expect(db.select('PRAGMA user_version').single.values.first, 13);
    expect(db.select('SELECT count(*) c FROM child').single['c'], 2);
    expect(db.select('SELECT q FROM v').single['q'], 12);
    db.execute('INSERT INTO child(parent_id, qty) VALUES (1, 1)');
    expect(db.select('SELECT count(*) c FROM audit').single['c'], 3);
    expect(db.select('PRAGMA integrity_check').single.values.first, 'ok');
    db.close();
  });

  test('rekey replaces the key', () {
    final a = SecretKey256.generate();
    final b = SecretKey256.generate();
    final db = openKeyed(path, a);
    db.execute('CREATE TABLE t(x); INSERT INTO t VALUES (1); PRAGMA user_version = 4;');
    db.close();
    rekeyDatabase(path, a.toHex(), b.toHex());
    expect(() => unlockCheck(path, a.toHex()), throwsA(isA<DatabaseSecurityException>()));
    final db2 = openKeyed(path, b);
    expect(db2.select('PRAGMA user_version').single.values.first, 4);
    db2.close();
  });

  group('EncryptedDatabaseOpener with the real library', () {
    late _Store store;
    late EncryptedDatabaseOpener opener;
    setUp(() {
      store = _Store();
      opener = EncryptedDatabaseOpener(
        path: path,
        keys: SecretKeyManager(store),
        gateway: const Sqlite3SqlcipherGateway(),
      );
    });

    test('migrates an existing plaintext database exactly once', () async {
      createPlain(path);
      final session = await opener.open();
      expect(isPlainHeader(path), isFalse);
      expect(
        dir.listSync().map((e) => e.uri.pathSegments.last).toList(),
        ['inventory_management.sqlite'],
      );
      final db = openKeyed(path, session.key);
      expect(db.select('SELECT name FROM parent').single['name'], 'Secret Customer Ltd');
      expect(db.select('PRAGMA user_version').single.values.first, 13);
      db.close();
      await opener.assertEncryptedOnDisk();

      final second = await opener.open(); // restart
      expect(second.key, session.key);
    });

    test('a lost key is reported, never replaced', () async {
      createPlain(path);
      await opener.open();
      store.values.clear(); // secure storage wiped
      await expectLater(
        opener.open(),
        throwsA(
          isA<DatabaseSecurityException>().having(
            (e) => e.problem,
            'problem',
            DatabaseSecurityProblem.keyMissing,
          ),
        ),
      );
      expect(store.values, isEmpty);
    });

    test('a different stored key is reported as unlock failure', () async {
      createPlain(path);
      await opener.open();
      store.values[SecretNames.databaseKey] = SecretKey256.generate().toHex();
      await expectLater(
        opener.open(),
        throwsA(
          isA<DatabaseSecurityException>().having(
            (e) => e.problem,
            'problem',
            DatabaseSecurityProblem.unlockFailed,
          ),
        ),
      );
    });
  });
}

class _Store implements SecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async => values[name] = value;
}
