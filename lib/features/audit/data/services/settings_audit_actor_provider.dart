import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_operator_repository.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_actor_provider.dart';

/// Actor from the app settings: the local operator name the business typed
/// (`audit_operator_name`), otherwise the device. A typed name is a label,
/// not proof of identity.
final class SettingsAuditActorProvider implements AuditActorProvider {
  /// Creates the provider.
  const SettingsAuditActorProvider(this._db);

  final AppDatabase _db;

  @override
  Future<AuditActor> current() async {
    try {
      final row = await _db
          .customSelect(
            "SELECT value FROM app_settings WHERE key = 'audit_operator_name'",
          )
          .getSingleOrNull();
      final name = row?.read<String>('value').trim() ?? '';
      return name.isEmpty ? AuditActor.device : AuditActor.localOperator(name);
    } on Object {
      return AuditActor.device;
    }
  }
}

/// Reads and writes the operator name in the app settings
/// (`audit_operator_name`).
final class SettingsAuditOperatorRepository implements AuditOperatorRepository {
  /// Creates the repository.
  const SettingsAuditOperatorRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<String?>> name() => guardDatabase(() async {
    final row = await _db
        .customSelect("SELECT value FROM app_settings WHERE key = 'audit_operator_name'")
        .getSingleOrNull();
    final value = row?.read<String>('value').trim() ?? '';
    return value.isEmpty ? null : value;
  });

  @override
  Future<Result<void>> save(String? name, DateTime now) => guardDatabase(() async {
    if (name == null || name.trim().isEmpty) {
      await _db.customStatement("DELETE FROM app_settings WHERE key = 'audit_operator_name'");
      return;
    }
    await _db.customStatement(
      "INSERT INTO app_settings (key, value, updated_at) VALUES ('audit_operator_name', ?, ?) "
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
      [name.trim(), toEpochMs(now)],
    );
  });
}
