import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:inventrix/features/backup/data/services/backup_envelope.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/entities/backup_manifest.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_key_provider.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// [BackupPackager] that wraps the ZIP packager in the authenticated
/// encryption container ([BackupEnvelope]).
///
/// The only plaintext intermediate is the ZIP payload in a private scratch
/// folder; it is overwritten and deleted in a `finally` block. The database
/// inside stays SQLCipher-encrypted at all times.
final class EncryptedBackupPackager implements BackupPackager {
  /// Creates the packager around [inner].
  EncryptedBackupPackager({
    required BackupPackager inner,
    required BackupKeyProvider keys,
    required BackupLocations locations,
    BackupEnvelope? envelope,
  }) : _inner = inner,
       _keys = keys,
       _locations = locations,
       _envelope = envelope ?? BackupEnvelope();

  final BackupPackager _inner;
  final BackupKeyProvider _keys;
  final BackupLocations _locations;
  final BackupEnvelope _envelope;
  final Logger _log = Logger('EncryptedBackupPackager');

  @override
  Future<Result<PackedBackup>> pack(PackRequest request) async {
    String? scratch;
    final partial = File('${request.outputPath}.part');
    try {
      scratch = await _locations.createTempDirectory('seal');
      final plain = p.join(scratch, 'payload.zip');
      final packed = await _inner.pack(
        PackRequest(
          databasePath: request.databasePath,
          dataFolders: request.dataFolders,
          outputPath: plain,
          createdAt: request.createdAt,
          appVersion: request.appVersion,
          schemaVersion: request.schemaVersion,
        ),
      );
      if (packed case Err<PackedBackup>(:final failure)) {
        return Result.failure(failure);
      }
      final deviceHex = (await _keys.deviceKey()).toHex();
      final dbHex = _keys.databaseKey?.toHex();
      final passphrase = request.recoveryPassphrase;
      final envelope = _envelope;
      final partialPath = partial.path;
      if (await partial.exists()) {
        await partial.delete();
      }
      await Isolate.run(
        () => envelope.seal(
          inputPath: plain,
          outputPath: partialPath,
          deviceKey: SecretKey256.tryParseHex(deviceHex)!,
          databaseKey: dbHex == null ? null : SecretKey256.tryParseHex(dbHex),
          passphrase: passphrase,
        ),
      );
      await partial.rename(request.outputPath);
      final output = File(request.outputPath);
      final checksum = await _inner.archiveChecksum(output.path);
      return Result.success(
        PackedBackup(
          path: output.path,
          sizeBytes: await output.length(),
          sha256: checksum.valueOrNull ?? '',
          manifest: packed.valueOrNull!.manifest,
        ),
      );
    } on Object catch (error, stackTrace) {
      _log.warning('Sealing failed', error, stackTrace);
      await _deleteQuietly(partial);
      return Result.failure(
        BackupFailure(
          'Could not write the encrypted backup file. Check that the device '
          'has enough free space.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      if (scratch != null) {
        await _wipeDirectory(scratch);
        await _locations.discard(scratch);
      }
    }
  }

  @override
  Future<Result<String>> archiveChecksum(String archivePath) =>
      _inner.archiveChecksum(archivePath);

  @override
  Future<Result<BackupManifest>> verify(
    String archivePath, {
    String? passphrase,
  }) async {
    String? scratch;
    try {
      scratch = await _locations.createTempDirectory('open');
      final opened = await _decrypt(archivePath, scratch, passphrase);
      if (opened case Err<_Decrypted>(:final failure)) {
        return Result.failure(failure);
      }
      return await _inner.verify(opened.valueOrNull!.zipPath);
    } finally {
      if (scratch != null) {
        await _wipeDirectory(scratch);
        await _locations.discard(scratch);
      }
    }
  }

  @override
  Future<Result<StagedBackup>> unpack({
    required String archivePath,
    required String stagingDirectory,
    String? passphrase,
  }) async {
    String? scratch;
    try {
      if (!await BackupEnvelope.isEnvelope(archivePath)) {
        return await _unpackLegacy(archivePath, stagingDirectory);
      }
      scratch = await _locations.createTempDirectory('open');
      final opened = await _decrypt(archivePath, scratch, passphrase);
      if (opened case Err<_Decrypted>(:final failure)) {
        return Result.failure(failure);
      }
      final decrypted = opened.valueOrNull!;
      final staged = await _inner.unpack(
        archivePath: decrypted.zipPath,
        stagingDirectory: stagingDirectory,
      );
      if (staged case Err<StagedBackup>(:final failure)) {
        return Result.failure(failure);
      }
      final source = File(archivePath);
      final checksum = await _inner.archiveChecksum(archivePath);
      return Result.success(
        staged.valueOrNull!.withSecurity(
          databaseKey: decrypted.databaseKey,
          sourceName: p.basename(archivePath),
          archiveSha256: checksum.valueOrNull,
          archiveSizeBytes: await source.length(),
        ),
      );
    } finally {
      if (scratch != null) {
        await _wipeDirectory(scratch);
        await _locations.discard(scratch);
      }
    }
  }

  Future<Result<StagedBackup>> _unpackLegacy(
    String archivePath,
    String stagingDirectory,
  ) async {
    final file = File(archivePath);
    if (!await file.exists()) {
      return const Result.failure(
        NotFoundFailure('The backup file could not be found.'),
      );
    }
    final raf = await file.open();
    final Uint8List head;
    try {
      head = await raf.read(4);
    } finally {
      await raf.close();
    }
    final isZip = head.length >= 2 && head[0] == 0x50 && head[1] == 0x4b;
    if (!isZip || !BackupFormat.allowLegacyPlaintextRestore) {
      return const Result.failure(
        RestoreFailure(
          'This file is not an encrypted Inventrix backup, so it was not '
          'used. Nothing was changed.',
        ),
      );
    }
    final staged = await _inner.unpack(
      archivePath: archivePath,
      stagingDirectory: stagingDirectory,
    );
    return staged.map((s) => s.withSecurity(isLegacyPlaintext: true));
  }

  Future<Result<_Decrypted>> _decrypt(
    String archivePath,
    String scratch,
    String? passphrase,
  ) async {
    final zipPath = p.join(scratch, 'payload.zip');
    try {
      final deviceHex = (await _keys.deviceKey()).toHex();
      final envelope = _envelope;
      final opened = await Isolate.run(
        () => envelope.open(
          inputPath: archivePath,
          outputPath: zipPath,
          deviceKey: SecretKey256.tryParseHex(deviceHex),
          passphrase: passphrase,
        ),
      );
      return Result.success(_Decrypted(zipPath, opened.databaseKey));
    } on BackupEnvelopeException catch (error) {
      return Result.failure(_failureFor(error));
    } on DatabaseSecurityException catch (error) {
      return Result.failure(RestoreFailure(error.message, cause: error));
    } on Object catch (error, stackTrace) {
      return Result.failure(
        RestoreFailure(
          'This backup could not be read. The file may be damaged or '
          'incomplete.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Failure _failureFor(BackupEnvelopeException error) =>
      switch (error.problem) {
        BackupEnvelopeProblem.passphraseRequired => BackupPassphraseFailure(
          'This backup was made on another device or installation. Enter '
          'its recovery passphrase to open it.',
          cause: error,
        ),
        BackupEnvelopeProblem.passphraseIncorrect => BackupPassphraseFailure(
          'That recovery passphrase is not correct.',
          incorrect: true,
          cause: error,
        ),
        _ => RestoreFailure(error.message, cause: error),
      };

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Nothing more can be done.
    }
  }

  /// Overwrites every file in [directory] with zeros before it is deleted.
  Future<void> _wipeDirectory(String directory) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) {
        return;
      }
      await for (final entity in dir.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final length = await entity.length();
        final raf = await entity.open(mode: FileMode.writeOnly);
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
      }
    } on FileSystemException catch (error) {
      _log.warning('Could not overwrite scratch files', error);
    }
  }
}

final class _Decrypted {
  const _Decrypted(this.zipPath, this.databaseKey);

  final String zipPath;
  final SecretKey256? databaseKey;
}
