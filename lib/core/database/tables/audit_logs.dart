import 'package:drift/drift.dart';

/// Append-only audit trail (updates and deletes are blocked by triggers).
@DataClassName('AuditLogRow')
@TableIndex(
  name: 'idx_audit_logs_entity',
  columns: {#entityType, #entityId, #occurredAt},
)
class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get summary => text()();
  IntColumn get occurredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
