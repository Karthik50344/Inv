import 'package:drift/drift.dart';

/// Hash-chained, append-only audit trail (updates and deletes are blocked by
/// triggers). `seq` gives the chain order; the hash fields tie each event to
/// the one before it.
@DataClassName('AuditEventRow')
@TableIndex(
  name: 'idx_audit_events_entity',
  columns: {#entityType, #entityId, #occurredAtUtc},
)
@TableIndex(name: 'idx_audit_events_type', columns: {#eventType, #occurredAtUtc})
@TableIndex(name: 'idx_audit_events_time', columns: {#occurredAtUtc})
@TableIndex(name: 'idx_audit_events_correlation', columns: {#correlationId})
class AuditEvents extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get id => text()();
  TextColumn get eventType => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get actorType => text()();
  TextColumn get actorId => text().nullable()();
  TextColumn get actorDisplayName => text()();
  IntColumn get occurredAtUtc => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get source => text()();
  TextColumn get correlationId => text()();
  TextColumn get previousValues => text().nullable()();
  TextColumn get newValues => text().nullable()();
  TextColumn get metadata => text().nullable()();
  TextColumn get previousEventHash => text()();
  TextColumn get eventHash => text()();
  IntColumn get schemaVersion => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {id},
    {eventHash},
  ];
}
