import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_event_repository.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// The `AuditLogRepository` every existing use case already calls, now
/// writing to the hash-chained audit events.
///
/// [record] is fail-closed: the existing use cases call it inside their
/// transaction and return its failure, so a business change is never
/// committed without its audit event. [forEntity] merges the new events with
/// the rows of the legacy `audit_logs` table, so earlier history stays
/// visible.
final class AuditEventLogRepository implements AuditLogRepository {
  /// Creates the adapter.
  const AuditEventLogRepository({
    required AuditRecorder recorder,
    required AuditEventRepository events,
    required AuditLogRepository legacy,
  }) : _recorder = recorder,
       _events = events,
       _legacy = legacy;

  final AuditRecorder _recorder;
  final AuditEventRepository _events;
  final AuditLogRepository _legacy;

  @override
  Future<Result<void>> record(AuditEntry entry) async {
    final result = await _recorder.record(
      AuditEventDraft(
        eventType: '${entry.entityType}.${entry.action}',
        entityType: entry.entityType,
        entityId: entry.entityId,
        action: entry.action,
        reason: entry.reason,
        previousValues: entry.previousValues,
        newValues: entry.newValues,
        metadata: {'summary': entry.summary, ...?entry.metadata},
        occurredAtUtc: entry.occurredAt.toUtc(),
      ),
    );
    return result.isSuccess
        ? const Result.success(null)
        : Result.failure(result.failureOrNull!);
  }

  @override
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) async {
    final fresh = await _events.forEntity(entityType, entityId, limit: limit);
    final events = fresh.valueOrNull;
    if (events == null) {
      return Result.failure(fresh.failureOrNull!);
    }
    final old = await _legacy.forEntity(entityType, entityId, limit: limit);
    final legacy = old.valueOrNull;
    if (legacy == null) {
      return Result.failure(old.failureOrNull!);
    }
    final merged = <AuditEntry>[
      for (final e in events)
        AuditEntry(
          id: e.id,
          entityType: e.entityType,
          entityId: e.entityId,
          action: e.action,
          summary: (e.metadata?['summary'] as String?) ?? e.eventType,
          occurredAt: e.occurredAtUtc,
          reason: e.reason,
          previousValues: e.previousValues,
          newValues: e.newValues,
        ),
      ...legacy,
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return Result.success(merged.take(limit).toList());
  }
}
