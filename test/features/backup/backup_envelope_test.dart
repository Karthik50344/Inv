import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/features/backup/data/services/backup_envelope.dart';

void main() {
  late Directory dir;
  // Small Argon2id cost keeps the tests fast; the format carries its own.
  final envelope = BackupEnvelope(argonMemoryKib: 64, argonIterations: 1);
  final device = SecretKey256.generate();
  final otherDevice = SecretKey256.generate();
  final dbKey = SecretKey256.generate();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ivx_env_');
  });
  tearDown(() => dir.delete(recursive: true));

  Uint8List payload(int length) =>
      Uint8List.fromList(List<int>.generate(length, (i) => (i * 31 + 7) & 255));

  Future<String> sealed(
    int length, {
    String? passphrase,
    SecretKey256? key,
  }) async {
    final input = File('${dir.path}/in.bin')..writeAsBytesSync(payload(length));
    final out = '${dir.path}/out.ivxbak';
    if (File(out).existsSync()) {
      File(out).deleteSync();
    }
    await envelope.seal(
      inputPath: input.path,
      outputPath: out,
      deviceKey: key ?? device,
      databaseKey: dbKey,
      passphrase: passphrase,
    );
    return out;
  }

  Future<BackupEnvelopeProblem?> opens(
    String path, {
    SecretKey256? key,
    String? passphrase,
  }) async {
    try {
      await envelope.open(
        inputPath: path,
        outputPath: '${dir.path}/dec.bin',
        deviceKey: key ?? device,
        passphrase: passphrase,
      );
      return null;
    } on BackupEnvelopeException catch (e) {
      expect(File('${dir.path}/dec.bin').existsSync(), isFalse);
      return e.problem;
    }
  }

  group('round trip', () {
    for (final length in [
      0,
      1,
      65535,
      65536,
      65537,
      131072,
      200000,
    ]) {
      test('$length bytes', () async {
        final path = await sealed(length);
        final result = await envelope.open(
          inputPath: path,
          outputPath: '${dir.path}/dec.bin',
          deviceKey: device,
        );
        expect(File('${dir.path}/dec.bin').readAsBytesSync(), payload(length));
        expect(result.databaseKey, dbKey);
        expect(result.usedPassphrase, isFalse);
      });
    }

    test('file is not a ZIP or SQLite file and hides the content', () async {
      final path = await sealed(100000);
      final bytes = File(path).readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 6)), 'IVXBAK');
      expect(String.fromCharCodes(bytes.sublist(0, 2)), isNot('PK'));
      expect(String.fromCharCodes(bytes.sublist(0, 15)), isNot('SQLite format 3'));
      expect(await BackupEnvelope.isEnvelope(path), isTrue);
      // Ciphertext does not contain a long run of the plaintext.
      final plain = payload(100000);
      final needle = String.fromCharCodes(plain.sublist(500, 532));
      expect(String.fromCharCodes(bytes).contains(needle), isFalse);
    });

    test('two backups of the same data differ', () async {
      final a = File(await sealed(5000)).readAsBytesSync();
      final b = File(await sealed(5000)).readAsBytesSync();
      expect(a, isNot(b));
    });
  });

  group('keys', () {
    test('another device needs the passphrase', () async {
      final path = await sealed(5000, passphrase: 'correct horse battery');
      expect(
        await opens(path, key: otherDevice),
        BackupEnvelopeProblem.passphraseRequired,
      );
      expect(
        await opens(path, key: otherDevice, passphrase: 'wrong'),
        BackupEnvelopeProblem.passphraseIncorrect,
      );
      final result = await envelope.open(
        inputPath: path,
        outputPath: '${dir.path}/dec2.bin',
        deviceKey: otherDevice,
        passphrase: 'correct horse battery',
      );
      expect(result.usedPassphrase, isTrue);
      expect(result.databaseKey, dbKey);
      expect(File('${dir.path}/dec2.bin').readAsBytesSync(), payload(5000));
    });

    test('without a passphrase slot another device cannot open it', () async {
      final path = await sealed(5000);
      expect(
        await opens(path, key: otherDevice),
        BackupEnvelopeProblem.noUsableKey,
      );
      expect(
        await opens(path, key: otherDevice, passphrase: 'anything'),
        BackupEnvelopeProblem.noUsableKey,
      );
    });
  });

  group('tampering is rejected', () {
    Future<void> expectRejected(
      String path,
      List<BackupEnvelopeProblem> allowed,
    ) async {
      final problem = await opens(path);
      expect(allowed, contains(problem));
    }

    Future<String> mutate(
      String path,
      Uint8List Function(Uint8List) change,
    ) async {
      final copy = '${dir.path}/mutated.ivxbak';
      File(copy).writeAsBytesSync(change(File(path).readAsBytesSync()));
      return copy;
    }

    test('flipped bit in every region', () async {
      final path = await sealed(150000);
      final length = File(path).lengthSync();
      for (final offset in [
        8, // header length
        12, // header text
        60,
        length ~/ 2,
        length - 1, // last tag byte
      ]) {
        final copy = await mutate(path, (b) => b..[offset] ^= 0x01);
        await expectRejected(copy, [
          BackupEnvelopeProblem.corrupt,
          BackupEnvelopeProblem.authenticationFailed,
          BackupEnvelopeProblem.noUsableKey,
          BackupEnvelopeProblem.unsupportedVersion,
        ]);
      }
    });

    test('truncated at a chunk boundary', () async {
      final path = await sealed(200000);
      final headerEnd = 12 +
          ByteData.sublistView(File(path).readAsBytesSync()).getUint32(8);
      final copy = await mutate(
        path,
        (b) => b.sublist(0, headerEnd + 2 * (65536 + 16)),
      );
      await expectRejected(copy, [BackupEnvelopeProblem.authenticationFailed]);
    });

    test('truncated in the middle and missing the end', () async {
      final path = await sealed(200000);
      for (final cut in [1, 10, 17, 40000]) {
        final copy = await mutate(path, (b) => b.sublist(0, b.length - cut));
        await expectRejected(copy, [
          BackupEnvelopeProblem.authenticationFailed,
          BackupEnvelopeProblem.corrupt,
        ]);
      }
    });

    test('data appended', () async {
      final path = await sealed(70000);
      final copy = await mutate(
        path,
        (b) => Uint8List.fromList([...b, ...List<int>.filled(100, 7)]),
      );
      await expectRejected(copy, [BackupEnvelopeProblem.authenticationFailed]);
    });

    test('chunks swapped', () async {
      final path = await sealed(3 * 65536 + 10);
      final headerEnd = 12 +
          ByteData.sublistView(File(path).readAsBytesSync()).getUint32(8);
      final copy = await mutate(path, (b) {
        final size = 65536 + 16;
        final a = b.sublist(headerEnd, headerEnd + size);
        final c = b.sublist(headerEnd + size, headerEnd + 2 * size);
        return b
          ..setAll(headerEnd, c)
          ..setAll(headerEnd + size, a);
      });
      await expectRejected(copy, [BackupEnvelopeProblem.authenticationFailed]);
    });

    test('empty, tiny, foreign and newer-version files', () async {
      final empty = File('${dir.path}/empty')..writeAsBytesSync([]);
      expect(await opens(empty.path), BackupEnvelopeProblem.notAnEnvelope);
      final zip = File('${dir.path}/z.zip')..writeAsBytesSync([0x50, 0x4b, 3, 4]);
      expect(await opens(zip.path), BackupEnvelopeProblem.notAnEnvelope);
      final magicOnly = File('${dir.path}/m')
        ..writeAsBytesSync('IVXBAK'.codeUnits);
      expect(await opens(magicOnly.path), BackupEnvelopeProblem.corrupt);
      final path = await sealed(100);
      final newer = await mutate(path, (b) => b..[7] = 9);
      expect(await opens(newer), BackupEnvelopeProblem.unsupportedVersion);
      final huge = await mutate(
        path,
        (b) => b
          ..[8] = 0x7f
          ..[9] = 0xff,
      );
      expect(await opens(huge), BackupEnvelopeProblem.corrupt);
    });
  });
}
