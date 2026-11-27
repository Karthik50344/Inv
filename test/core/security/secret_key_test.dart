import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/core/security/secret_store.dart';

class _MemoryStore implements SecretStore {
  final Map<String, String> values = {};
  bool failRead = false;
  bool dropWrites = false;

  @override
  Future<String?> read(String name) async {
    if (failRead) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.keyStorageUnavailable,
        'unavailable',
      );
    }
    return values[name];
  }

  @override
  Future<void> write(String name, String value) async {
    if (!dropWrites) {
      values[name] = value;
    }
  }
}

void main() {
  test('generated keys are 32 random bytes and never printed', () {
    final a = SecretKey256.generate();
    final b = SecretKey256.generate();
    expect(a.bytes.length, 32);
    expect(a.toHex().length, 64);
    expect(a == b, isFalse);
    expect(a.toString().contains(a.toHex()), isFalse);
    expect(a.sqlcipherRawKey, "x'${a.toHex()}'");
  });

  test('hex round trip and rejects malformed text', () {
    final a = SecretKey256.generate();
    expect(SecretKey256.tryParseHex(a.toHex()), a);
    expect(SecretKey256.tryParseHex('abc'), isNull);
    expect(SecretKey256.tryParseHex('z' * 64), isNull);
    expect(SecretKey256.tryParseHex("x'${a.toHex()}'"), isNull);
  });

  test('manager creates once, reads back, never replaces a damaged value', () async {
    final store = _MemoryStore();
    final manager = SecretKeyManager(store);
    expect(await manager.readExisting('k'), isNull);
    final created = await manager.createNew('k');
    expect(await manager.readExisting('k'), created);

    store.values['k'] = 'not-a-key';
    await expectLater(
      manager.readExisting('k'),
      throwsA(
        isA<DatabaseSecurityException>().having(
          (e) => e.problem,
          'problem',
          DatabaseSecurityProblem.keyInvalid,
        ),
      ),
    );
    expect(store.values['k'], 'not-a-key');
  });

  test('a store that does not persist is detected', () async {
    final store = _MemoryStore()..dropWrites = true;
    await expectLater(
      SecretKeyManager(store).createNew('k'),
      throwsA(isA<DatabaseSecurityException>()),
    );
  });

  test('storage errors propagate instead of looking like a missing key', () async {
    final store = _MemoryStore()..failRead = true;
    await expectLater(
      SecretKeyManager(store).readExisting('k'),
      throwsA(isA<DatabaseSecurityException>()),
    );
  });
}
