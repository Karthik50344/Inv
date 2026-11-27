import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:inventrix/core/security/secret_store.dart';

/// [SecretStore] on the Android Keystore / iOS Keychain through
/// `flutter_secure_storage`.
///
/// * `resetOnError: false`: the plugin's default would silently **erase**
///   everything it holds when it hits a Keystore error, destroying the
///   database key. Here an error is reported and nothing is deleted.
/// * iOS: `first_unlock_this_device`: readable after the first unlock since
///   boot, never synced to iCloud and not restored onto another device.
final class SecureStorageSecretStore implements SecretStore {
  /// Creates the store.
  const SecureStorageSecretStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) async {
    try {
      return await _storage.read(key: name);
    } on PlatformException catch (error) {
      throw DatabaseSecurityException(
        DatabaseSecurityProblem.keyStorageUnavailable,
        'The secure storage of this device could not be read. Nothing was '
        'deleted or reset. Restart the phone and try again; if it keeps '
        'happening, contact support before reinstalling.',
        cause: error,
      );
    }
  }

  @override
  Future<void> write(String name, String value) async {
    try {
      await _storage.write(key: name, value: value);
    } on PlatformException catch (error) {
      throw DatabaseSecurityException(
        DatabaseSecurityProblem.keyStorageUnavailable,
        'The secure storage of this device could not be written, so no '
        'data was created.',
        cause: error,
      );
    }
  }
}
