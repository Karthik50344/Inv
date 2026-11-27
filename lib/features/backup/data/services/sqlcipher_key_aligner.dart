import 'dart:io';
import 'dart:isolate';

import 'package:inventrix/core/database/sqlcipher_gateway_impl.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/features/backup/domain/repositories/database_key_aligner.dart';
import 'package:logging/logging.dart';

/// [DatabaseKeyAligner] using SQLCipher `PRAGMA rekey` (or an encrypted
/// export for a plain legacy file).
final class SqlcipherKeyAligner implements DatabaseKeyAligner {
  /// Creates the aligner.
  SqlcipherKeyAligner();

  final Logger _log = Logger('SqlcipherKeyAligner');

  @override
  Future<Result<void>> align(
    String path, {
    required SecretKey256? currentKey,
    required SecretKey256 targetKey,
  }) async {
    try {
      final to = targetKey.toHex();
      if (currentKey == null) {
        final sealed = '$path.sealed';
        await Isolate.run(() => encryptPlaintextCopy(path, sealed, to));
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          final old = File('$path$suffix');
          if (await old.exists()) {
            await old.delete();
          }
        }
        await File(sealed).rename(path);
      } else if (!currentKey.sameAs(targetKey)) {
        final from = currentKey.toHex();
        await Isolate.run(() => rekeyDatabase(path, from, to));
      }
      return const Result.success(null);
    } on Object catch (error, stackTrace) {
      _log.warning('Re-keying the staged database failed', error, stackTrace);
      return Result.failure(
        RestoreFailure(
          'The backup could not be prepared for this device. Nothing was '
          'changed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
