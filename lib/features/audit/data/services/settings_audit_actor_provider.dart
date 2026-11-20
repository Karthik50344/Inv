import 'package:inventrix/core/database/app_database.dart';
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
