import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/security/database_key.dart';

/// Makes a staged database file use this device's database key, so that
/// after a restore the live database opens with the key held in secure
/// storage.
abstract interface class DatabaseKeyAligner {
  /// Re-encrypts the file at [path]. [currentKey] is the key the file has now
  /// (`null` = plain, unencrypted file); [targetKey] is the key it must have.
  /// Does nothing if they are already the same.
  Future<Result<void>> align(
    String path, {
    required SecretKey256? currentKey,
    required SecretKey256 targetKey,
  });
}
