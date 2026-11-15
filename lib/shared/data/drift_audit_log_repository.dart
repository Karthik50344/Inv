import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Drift implementation of [AuditLogRepository].
final class DriftAuditLogRepository implements AuditLogRepository {
  /// Creates the repository.
  const DriftAuditLogRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<void>> record(AuditEntry entry) => guardDatabase(
    () => _db
        .into(_db.auditLogs)
        .insert(
          AuditLogsCompanion(
            id: Value(entry.id),
            entityType: Value(entry.entityType),
            entityId: Value(entry.entityId),
            action: Value(entry.action),
            summary: Value(entry.summary),
            occurredAt: Value(toEpochMs(entry.occurredAt)),
          ),
        ),
  );

  @override
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) => guardDatabase(() async {
    final query = _db.select(_db.auditLogs)
      ..where(
        (t) => t.entityType.equals(entityType) & t.entityId.equals(entityId),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm(
          expression: const CustomExpression<int>('rowid'),
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit);
    return (await query.get())
        .map(
          (row) => AuditEntry(
            id: row.id,
            entityType: row.entityType,
            entityId: row.entityId,
            action: row.action,
            summary: row.summary,
            occurredAt: fromEpochMs(row.occurredAt),
          ),
        )
        .toList();
  });
}
