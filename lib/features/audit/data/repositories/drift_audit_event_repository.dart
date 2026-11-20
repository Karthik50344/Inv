import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_event_repository.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';

/// Drift implementation of [AuditEventRepository].
final class DriftAuditEventRepository implements AuditEventRepository {
  /// Creates the repository.
  const DriftAuditEventRepository(this._db);

  final AppDatabase _db;

  static String? _json(Map<String, Object?>? values) =>
      values == null ? null : AuditCanonical.encode(values);

  static Map<String, Object?>? _decode(String? text) => text == null
      ? null
      : (jsonDecode(text) as Map<Object?, Object?>).cast<String, Object?>();

  static AuditEvent map(AuditEventRow r) => AuditEvent.stored(
    id: r.id,
    sequence: r.seq,
    eventType: r.eventType,
    entityType: r.entityType,
    entityId: r.entityId,
    action: r.action,
    actor: AuditActor(
      type: AuditActorType.parse(r.actorType),
      id: r.actorId,
      displayName: r.actorDisplayName,
    ),
    occurredAtUtc: DateTime.fromMillisecondsSinceEpoch(
      r.occurredAtUtc,
      isUtc: true,
    ),
    reason: r.reason,
    source: r.source,
    correlationId: r.correlationId,
    previousValues: _decode(r.previousValues),
    newValues: _decode(r.newValues),
    metadata: _decode(r.metadata),
    previousEventHash: r.previousEventHash,
    eventHash: r.eventHash,
    schemaVersion: r.schemaVersion,
  );

  AuditEventsCompanion _companion(AuditEvent e) => AuditEventsCompanion.insert(
    id: e.id,
    eventType: e.eventType,
    entityType: e.entityType,
    entityId: e.entityId,
    action: e.action,
    actorType: e.actor.type.code,
    actorId: Value(e.actor.id),
    actorDisplayName: e.actor.displayName,
    occurredAtUtc: toEpochMs(e.occurredAtUtc),
    reason: Value(e.reason),
    source: e.source,
    correlationId: e.correlationId,
    previousValues: Value(_json(e.previousValues)),
    newValues: Value(_json(e.newValues)),
    metadata: Value(_json(e.metadata)),
    previousEventHash: e.previousEventHash,
    eventHash: e.eventHash,
    schemaVersion: e.schemaVersion,
  );

  @override
  Future<Result<AuditEvent>> appendChained(
    AuditEvent Function(String previousHash) seal, {
    AuditEvent Function(String previousHash)? genesis,
  }) => guardDatabase(
    () => _db.transaction(() async {
      final last =
          await (_db.select(_db.auditEvents)
                ..orderBy([(t) => OrderingTerm.desc(t.seq)])
                ..limit(1))
              .getSingleOrNull();
      var previous = last?.eventHash;
      if (previous == null) {
        previous = kAuditGenesisHash;
        if (genesis != null) {
          final start = genesis(previous);
          await _db.into(_db.auditEvents).insert(_companion(start));
          previous = start.eventHash;
        }
      }
      final event = seal(previous);
      final seq = await _db.into(_db.auditEvents).insert(_companion(event));
      return AuditEvent.stored(
        id: event.id,
        sequence: seq,
        eventType: event.eventType,
        entityType: event.entityType,
        entityId: event.entityId,
        action: event.action,
        actor: event.actor,
        occurredAtUtc: event.occurredAtUtc,
        reason: event.reason,
        source: event.source,
        correlationId: event.correlationId,
        previousValues: event.previousValues,
        newValues: event.newValues,
        metadata: event.metadata,
        previousEventHash: event.previousEventHash,
        eventHash: event.eventHash,
        schemaVersion: event.schemaVersion,
      );
    }),
  );

  @override
  Future<Result<int>> legacyLogCount() => guardDatabase(() async {
    final row = await _db
        .customSelect('SELECT COUNT(*) AS c FROM audit_logs')
        .getSingle();
    return row.read<int>('c');
  });

  @override
  Future<Result<List<AuditEvent>>> page({
    int afterSequence = 0,
    int limit = 500,
  }) => guardDatabase(() async {
    final rows =
        await (_db.select(_db.auditEvents)
              ..where((t) => t.seq.isBiggerThanValue(afterSequence))
              ..orderBy([(t) => OrderingTerm.asc(t.seq)])
              ..limit(limit))
            .get();
    return rows.map(map).toList();
  });

  @override
  Future<Result<AuditEvent?>> latest() => guardDatabase(() async {
    final row =
        await (_db.select(_db.auditEvents)
              ..orderBy([(t) => OrderingTerm.desc(t.seq)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : map(row);
  });

  @override
  Future<Result<List<AuditEvent>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) => guardDatabase(() async {
    final rows =
        await (_db.select(_db.auditEvents)
              ..where(
                (t) =>
                    t.entityType.equals(entityType) &
                    t.entityId.equals(entityId),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.seq)])
              ..limit(limit))
            .get();
    return rows.map(map).toList();
  });

  @override
  Future<Result<void>> enqueue(String id, AuditEventDraft draft, DateTime at) =>
      guardDatabase(
        () => _db
            .into(_db.auditOutbox)
            .insert(
              AuditOutboxCompanion.insert(
                id: id,
                payload: AuditCanonical.encode(draft.toJson()),
                createdAt: toEpochMs(at),
              ),
            ),
      );

  @override
  Future<Result<List<QueuedAuditEvent>>> queued() => guardDatabase(() async {
    final rows =
        await (_db.select(_db.auditOutbox)
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [
      for (final r in rows)
        QueuedAuditEvent(
          id: r.id,
          draft: AuditEventDraft.fromJson(
            (jsonDecode(r.payload) as Map<Object?, Object?>)
                .cast<String, Object?>(),
          ),
          createdAt: fromEpochMs(r.createdAt),
          attempts: r.attempts,
        ),
    ];
  });

  @override
  Future<Result<void>> dequeue(String id) => guardDatabase(
    () async =>
        (_db.delete(_db.auditOutbox)..where((t) => t.id.equals(id))).go(),
  );

  @override
  Future<Result<void>> markAttempt(String id, String error) => guardDatabase(
    () async => _db.customStatement(
      'UPDATE audit_outbox SET attempts = attempts + 1, last_error = ? '
      'WHERE id = ?',
      [error, id],
    ),
  );
}
