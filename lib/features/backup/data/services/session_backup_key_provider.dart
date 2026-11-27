import 'package:inventrix/core/database/database_session.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_key_provider.dart';

/// [BackupKeyProvider] backed by the secret store and the unlocked database.
final class SessionBackupKeyProvider implements BackupKeyProvider {
  /// Creates the provider; [session] is `null` only in tests.
  const SessionBackupKeyProvider({
    required SecretKeyManager keys,
    required DatabaseSession? session,
  }) : _keys = keys,
       _session = session;

  final SecretKeyManager _keys;
  final DatabaseSession? _session;

  @override
  Future<SecretKey256> deviceKey() async =>
      await _keys.readExisting(SecretNames.backupDeviceKey) ??
      await _keys.createNew(SecretNames.backupDeviceKey);

  @override
  SecretKey256? get databaseKey => _session?.key;
}
