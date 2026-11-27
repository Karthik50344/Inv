import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:inventrix/core/security/database_key.dart';

/// Why a backup container could not be read.
enum BackupEnvelopeProblem {
  /// The file does not start with the Inventrix backup signature.
  notAnEnvelope,

  /// Written by a newer, unknown version of the format.
  unsupportedVersion,

  /// Header or structure is damaged or implausible.
  corrupt,

  /// Content failed authentication: modified, damaged or truncated.
  authenticationFailed,

  /// This installation cannot open it; a recovery passphrase is needed.
  passphraseRequired,

  /// The recovery passphrase is wrong.
  passphraseIncorrect,

  /// Neither this installation nor a passphrase can open it.
  noUsableKey,
}

/// A backup container could not be read.
final class BackupEnvelopeException implements Exception {
  /// Creates the exception.
  const BackupEnvelopeException(this.problem, this.message);

  /// Category.
  final BackupEnvelopeProblem problem;

  /// User-safe message.
  final String message;

  @override
  String toString() => 'BackupEnvelopeException($problem): $message';
}

/// What opening a container yields.
final class OpenedEnvelope {
  /// Creates the result.
  const OpenedEnvelope({
    required this.databaseKey,
    required this.usedPassphrase,
  });

  /// Key of the database inside the payload; `null` if none was recorded.
  final SecretKey256? databaseKey;

  /// Whether the recovery passphrase (not this device) unlocked it.
  final bool usedPassphrase;
}

/// Authenticated encryption container for backups ("IVXBAK" format v1).
///
/// ```text
/// "IVXBAK" | version u16 | headerLength u32 | header (JSON) | chunks...
/// ```
/// * A random 256-bit data key (DEK) encrypts the payload in 64 KiB chunks
///   with AES-256-GCM. The nonce of chunk *i* is `prefix(7) | i(4) | last(1)`
///   and the whole prefix including the header is authenticated data of every
///   chunk, so reordering, truncating, extending or editing the header is
///   detected (STREAM construction).
/// * The DEK is wrapped in key slots: a `device` slot (HKDF of this
///   installation's backup key) and an optional `passphrase` slot
///   (Argon2id). Nothing in the file reveals either secret.
/// * The key of the database inside the payload is wrapped with the DEK so a
///   restore on another device can open it and re-key it to its own key.
final class BackupEnvelope {
  /// Creates the codec. Argon2id parameters apply to newly written files;
  /// files carry their own.
  BackupEnvelope({this.argonMemoryKib = 19456, this.argonIterations = 2});

  /// Argon2id memory in KiB for new files (OWASP minimum: 19 MiB).
  final int argonMemoryKib;

  /// Argon2id passes for new files.
  final int argonIterations;

  static const List<int> _magic = [0x49, 0x56, 0x58, 0x42, 0x41, 0x4b];
  static const int _version = 1;
  static const int chunkSize = 64 * 1024;
  static const int _tagLength = 16;
  static const int _maxHeaderBytes = 16 * 1024;
  static const int _maxArgonMemoryKib = 256 * 1024;
  static const int _maxArgonIterations = 10;
  static const String _deviceInfo = 'inventrix/backup/device-slot/v1';
  static final AesGcm _aes = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Whether [path] starts with the container signature.
  static Future<bool> isEnvelope(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return false;
    }
    final raf = await file.open();
    try {
      final head = await raf.read(_magic.length);
      if (head.length != _magic.length) {
        return false;
      }
      for (var i = 0; i < _magic.length; i++) {
        if (head[i] != _magic[i]) {
          return false;
        }
      }
      return true;
    } finally {
      await raf.close();
    }
  }

  // ------------------------------------------------------------------ seal

  /// Encrypts [inputPath] into the new file [outputPath].
  Future<void> seal({
    required String inputPath,
    required String outputPath,
    required SecretKey256 deviceKey,
    SecretKey256? databaseKey,
    String? passphrase,
  }) async {
    final dek = SecretKey256.generate();
    final noncePrefix = _random(7);

    final slots = <Map<String, Object?>>[];
    final deviceSalt = _random(32);
    final deviceKek = await _deviceKek(deviceKey, deviceSalt);
    slots.add({
      'type': 'device',
      'kdf': 'hkdf-sha256',
      'salt': base64.encode(deviceSalt),
      ..._wrap(await _wrapKey(deviceKek, dek.bytes, 'slot:device')),
    });
    if (passphrase != null && passphrase.isNotEmpty) {
      final salt = _random(16);
      final kek = await _passphraseKek(
        passphrase,
        salt,
        argonMemoryKib,
        argonIterations,
        1,
      );
      slots.add({
        'type': 'passphrase',
        'kdf': 'argon2id',
        'm': argonMemoryKib,
        't': argonIterations,
        'p': 1,
        'salt': base64.encode(salt),
        ..._wrap(await _wrapKey(kek, dek.bytes, 'slot:passphrase')),
      });
    }
    final header = <String, Object?>{
      'v': _version,
      'cipher': 'aes-256-gcm',
      'chunk': chunkSize,
      'noncePrefix': base64.encode(noncePrefix),
      'slots': slots,
      if (databaseKey != null)
        'dbKey': _wrap(
          await _wrapKey(SecretKey(dek.bytes), databaseKey.bytes, 'dbkey'),
        ),
    };
    final headerBytes = utf8.encode(jsonEncode(header));
    final prefix = _prefix(headerBytes);

    final output = await File(outputPath).open(mode: FileMode.writeOnly);
    final input = await File(inputPath).open();
    try {
      await output.writeFrom(prefix);
      var index = 0;
      var current = await _readUpTo(input, chunkSize);
      while (true) {
        final next = current.length == chunkSize
            ? await _readUpTo(input, chunkSize)
            : Uint8List(0);
        final last = next.isEmpty;
        final box = await _aes.encrypt(
          current,
          secretKey: SecretKey(dek.bytes),
          nonce: _chunkNonce(noncePrefix, index, last: last),
          aad: prefix,
        );
        await output.writeFrom(box.cipherText);
        await output.writeFrom(box.mac.bytes);
        if (last) {
          break;
        }
        current = next;
        index++;
      }
      await output.flush();
    } finally {
      await input.close();
      await output.close();
    }
  }

  // ------------------------------------------------------------------ open

  /// Decrypts [inputPath] into the new file [outputPath]. Any failure
  /// deletes [outputPath].
  Future<OpenedEnvelope> open({
    required String inputPath,
    required String outputPath,
    SecretKey256? deviceKey,
    String? passphrase,
  }) async {
    final input = await File(inputPath).open();
    var succeeded = false;
    try {
      final parsed = await _readHeader(input);
      final (dek, usedPassphrase) = await _unlock(
        parsed,
        deviceKey,
        passphrase,
      );
      final output = await File(outputPath).open(mode: FileMode.writeOnly);
      try {
        await _decryptChunks(input, output, parsed, dek);
        await output.flush();
      } finally {
        await output.close();
      }
      SecretKey256? databaseKey;
      final wrapped = parsed.header['dbKey'];
      if (wrapped is Map<String, Object?>) {
        databaseKey = SecretKey256(
          await _unwrapKey(SecretKey(dek.bytes), wrapped, 'dbkey'),
        );
      }
      succeeded = true;
      return OpenedEnvelope(
        databaseKey: databaseKey,
        usedPassphrase: usedPassphrase,
      );
    } finally {
      await input.close();
      if (!succeeded) {
        final out = File(outputPath);
        if (await out.exists()) {
          await out.delete();
        }
      }
    }
  }

  Future<void> _decryptChunks(
    RandomAccessFile input,
    RandomAccessFile output,
    _Parsed parsed,
    SecretKey256 dek,
  ) async {
    final size = parsed.chunk;
    final noncePrefix = parsed.noncePrefix;
    var index = 0;
    var current = await _readUpTo(input, size + _tagLength);
    if (current.isEmpty) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.corrupt,
        'This backup file is incomplete.',
      );
    }
    while (true) {
      final next = current.length == size + _tagLength
          ? await _readUpTo(input, size + _tagLength)
          : Uint8List(0);
      final last = next.isEmpty;
      if (current.length < _tagLength) {
        throw const BackupEnvelopeException(
          BackupEnvelopeProblem.corrupt,
          'This backup file is incomplete.',
        );
      }
      final cut = current.length - _tagLength;
      final List<int> clear;
      try {
        clear = await _aes.decrypt(
          SecretBox(
            Uint8List.sublistView(current, 0, cut),
            nonce: _chunkNonce(noncePrefix, index, last: last),
            mac: Mac(Uint8List.sublistView(current, cut)),
          ),
          secretKey: SecretKey(dek.bytes),
          aad: parsed.prefix,
        );
      } on SecretBoxAuthenticationError {
        throw const BackupEnvelopeException(
          BackupEnvelopeProblem.authenticationFailed,
          'This backup has been modified, damaged or cut short, so it was '
          'rejected. Nothing was changed.',
        );
      }
      await output.writeFrom(clear);
      if (last) {
        return;
      }
      current = next;
      index++;
    }
  }

  Future<_Parsed> _readHeader(RandomAccessFile input) async {
    final fixed = await _readUpTo(input, _magic.length + 2 + 4);
    if (fixed.length < _magic.length || !_startsWithMagic(fixed)) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.notAnEnvelope,
        'This is not an encrypted Inventrix backup.',
      );
    }
    if (fixed.length < _magic.length + 6) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.corrupt,
        'This backup file is incomplete.',
      );
    }
    final data = ByteData.sublistView(fixed);
    final version = data.getUint16(_magic.length);
    if (version != _version) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.unsupportedVersion,
        'This backup was made by a newer version of the app. Update the '
        'app and try again.',
      );
    }
    final headerLength = data.getUint32(_magic.length + 2);
    if (headerLength == 0 || headerLength > _maxHeaderBytes) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.corrupt,
        'This backup file is damaged.',
      );
    }
    final headerBytes = await _readUpTo(input, headerLength);
    if (headerBytes.length != headerLength) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.corrupt,
        'This backup file is incomplete.',
      );
    }
    final Map<String, Object?> header;
    try {
      final decoded = jsonDecode(utf8.decode(headerBytes));
      header = (decoded as Map).cast<String, Object?>();
      final chunk = header['chunk'];
      if (header['v'] != _version ||
          header['cipher'] != 'aes-256-gcm' ||
          chunk is! int ||
          chunk < 1024 ||
          chunk > 1024 * 1024 ||
          header['slots'] is! List) {
        throw const FormatException('bad header');
      }
      final prefixBytes = base64.decode(header['noncePrefix']! as String);
      if (prefixBytes.length != 7) {
        throw const FormatException('bad nonce prefix');
      }
    } on Object {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.corrupt,
        'This backup file is damaged.',
      );
    }
    final prefix = Uint8List(fixed.length + headerBytes.length)
      ..setAll(0, fixed)
      ..setAll(fixed.length, headerBytes);
    return _Parsed(
      header: header,
      prefix: prefix,
      chunk: header['chunk']! as int,
      noncePrefix: base64.decode(header['noncePrefix']! as String),
    );
  }

  Future<(SecretKey256, bool)> _unlock(
    _Parsed parsed,
    SecretKey256? deviceKey,
    String? passphrase,
  ) async {
    final slots = (parsed.header['slots']! as List)
        .whereType<Map<dynamic, dynamic>>()
        .map((s) => s.cast<String, Object?>())
        .toList();
    Map<String, Object?>? slotOf(String type) {
      for (final s in slots) {
        if (s['type'] == type) {
          return s;
        }
      }
      return null;
    }

    final device = slotOf('device');
    if (device != null && deviceKey != null) {
      try {
        final kek = await _deviceKek(
          deviceKey,
          base64.decode(device['salt']! as String),
        );
        return (
          SecretKey256(await _unwrapKey(kek, device, 'slot:device')),
          false,
        );
      } on SecretBoxAuthenticationError {
        // Made on another installation; fall through to the passphrase.
      } on Object catch (error) {
        if (error is BackupEnvelopeException) {
          rethrow;
        }
        throw const BackupEnvelopeException(
          BackupEnvelopeProblem.corrupt,
          'This backup file is damaged.',
        );
      }
    }
    final slot = slotOf('passphrase');
    if (slot == null) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.noUsableKey,
        'This backup was made on another device or installation and has no '
        'recovery passphrase, so it cannot be opened here.',
      );
    }
    if (passphrase == null || passphrase.isEmpty) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.passphraseRequired,
        'Enter the recovery passphrase of this backup.',
      );
    }
    final memory = slot['m'];
    final iterations = slot['t'];
    final parallelism = slot['p'];
    if (slot['kdf'] != 'argon2id' ||
        memory is! int ||
        iterations is! int ||
        parallelism is! int ||
        memory < 8 ||
        memory > _maxArgonMemoryKib ||
        iterations < 1 ||
        iterations > _maxArgonIterations ||
        parallelism < 1 ||
        parallelism > 4) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.corrupt,
        'This backup file is damaged.',
      );
    }
    try {
      final kek = await _passphraseKek(
        passphrase,
        base64.decode(slot['salt']! as String),
        memory,
        iterations,
        parallelism,
      );
      return (
        SecretKey256(await _unwrapKey(kek, slot, 'slot:passphrase')),
        true,
      );
    } on SecretBoxAuthenticationError {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.passphraseIncorrect,
        'That recovery passphrase is not correct.',
      );
    }
  }

  // --------------------------------------------------------------- helpers

  static Uint8List _prefix(List<int> headerBytes) {
    final out = BytesBuilder()
      ..add(_magic)
      ..add((ByteData(2)..setUint16(0, _version)).buffer.asUint8List())
      ..add(
        (ByteData(4)..setUint32(0, headerBytes.length)).buffer.asUint8List(),
      )
      ..add(headerBytes);
    return out.toBytes();
  }

  static bool _startsWithMagic(Uint8List bytes) {
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) {
        return false;
      }
    }
    return true;
  }

  static List<int> _chunkNonce(
    List<int> prefix7,
    int index, {
    required bool last,
  }) {
    final nonce = Uint8List(12)..setAll(0, prefix7);
    ByteData.sublistView(nonce).setUint32(7, index);
    nonce[11] = last ? 1 : 0;
    return nonce;
  }

  static Future<SecretKey> _deviceKek(SecretKey256 deviceKey, List<int> salt) =>
      _hkdf.deriveKey(
        secretKey: SecretKey(deviceKey.bytes),
        nonce: salt,
        info: utf8.encode(_deviceInfo),
      );

  static Future<SecretKey> _passphraseKek(
    String passphrase,
    List<int> salt,
    int memoryKib,
    int iterations,
    int parallelism,
  ) => Argon2id(
    memory: memoryKib,
    parallelism: parallelism,
    iterations: iterations,
    hashLength: 32,
  ).deriveKeyFromPassword(password: passphrase, nonce: salt);

  static Future<SecretBox> _wrapKey(
    SecretKey kek,
    List<int> key,
    String purpose,
  ) => _aes.encrypt(
    key,
    secretKey: kek,
    nonce: _aes.newNonce(),
    aad: utf8.encode('ivx-wrap-v1:$purpose'),
  );

  static Future<List<int>> _unwrapKey(
    SecretKey kek,
    Map<String, Object?> entry,
    String purpose,
  ) async {
    final nonce = base64.decode(entry['nonce']! as String);
    final wrapped = base64.decode(entry['wrapped']! as String);
    if (nonce.length != 12 || wrapped.length != 32 + _tagLength) {
      throw const BackupEnvelopeException(
        BackupEnvelopeProblem.corrupt,
        'This backup file is damaged.',
      );
    }
    return _aes.decrypt(
      SecretBox(
        wrapped.sublist(0, 32),
        nonce: nonce,
        mac: Mac(wrapped.sublist(32)),
      ),
      secretKey: kek,
      aad: utf8.encode('ivx-wrap-v1:$purpose'),
    );
  }

  static Map<String, Object?> _wrap(SecretBox box) => {
    'nonce': base64.encode(box.nonce),
    'wrapped': base64.encode([...box.cipherText, ...box.mac.bytes]),
  };

  static Uint8List _random(int length) =>
      Uint8List.fromList(SecretKey256.generate().bytes.sublist(0, length));

  static Future<Uint8List> _readUpTo(RandomAccessFile file, int length) async {
    final out = BytesBuilder(copy: false);
    var left = length;
    while (left > 0) {
      final part = await file.read(left);
      if (part.isEmpty) {
        break;
      }
      out.add(part);
      left -= part.length;
    }
    return out.takeBytes();
  }
}

final class _Parsed {
  const _Parsed({
    required this.header,
    required this.prefix,
    required this.chunk,
    required this.noncePrefix,
  });

  final Map<String, Object?> header;
  final Uint8List prefix;
  final int chunk;
  final List<int> noncePrefix;
}
