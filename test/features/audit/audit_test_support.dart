import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/audit/data/services/sha256_audit_hasher.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_event_repository.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';

const hasher = Sha256AuditHasher();

class StepClock implements Clock {
  StepClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 6, 1, 10);
  DateTime _now;

  @override
  DateTime now() {
    final value = _now;
    _now = _now.add(const Duration(seconds: 1));
    return value;
  }
}

class CountingIds implements IdGenerator {
  int _n = 0;

  @override
  String newId() => 'id-${++_n}';
}

class FixedActor implements AuditActorProvider {
  FixedActor(this.actor);
  AuditActor actor;

  @override
  Future<AuditActor> current() async => actor;
}

/// In-memory chain with failure injection.
class MemoryAuditRepository implements AuditEventRepository {
  final List<AuditEvent> events = [];
  final List<QueuedAuditEvent> outbox = [];
  bool failAppend = false;
  bool failEnqueue = false;
  int legacyCount = 0;
  int _seq = 0;

  @override
  Future<Result<AuditEvent>> appendChained(
    AuditEvent Function(String previousHash) seal, {
    AuditEvent Function(String previousHash)? genesis,
  }) async {
    if (failAppend) {
      return const Result.failure(DatabaseFailure('disk full'));
    }
    var previous = events.isEmpty ? kAuditGenesisHash : events.last.eventHash;
    if (events.isEmpty && genesis != null) {
      final g = genesis(previous);
      events.add(_withSeq(g));
      previous = g.eventHash;
    }
    final e = _withSeq(seal(previous));
    events.add(e);
    return Result.success(e);
  }

  AuditEvent _withSeq(AuditEvent e) => AuditEvent.stored(
    id: e.id,
    sequence: ++_seq,
    eventType: e.eventType,
    entityType: e.entityType,
    entityId: e.entityId,
    action: e.action,
    actor: e.actor,
    occurredAtUtc: e.occurredAtUtc,
    reason: e.reason,
    source: e.source,
    correlationId: e.correlationId,
    previousValues: e.previousValues,
    newValues: e.newValues,
    metadata: e.metadata,
    previousEventHash: e.previousEventHash,
    eventHash: e.eventHash,
    schemaVersion: e.schemaVersion,
  );

  @override
  Future<Result<int>> legacyLogCount() async => Result.success(legacyCount);

  @override
  Future<Result<List<AuditEvent>>> page({
    int afterSequence = 0,
    int limit = 500,
  }) async => Result.success(
    events.where((e) => e.sequence! > afterSequence).take(limit).toList(),
  );

  @override
  Future<Result<AuditEvent?>> latest() async =>
      Result.success(events.isEmpty ? null : events.last);

  @override
  Future<Result<List<AuditEvent>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) async => Result.success(
    events
        .where((e) => e.entityType == entityType && e.entityId == entityId)
        .toList()
        .reversed
        .take(limit)
        .toList(),
  );

  @override
  Future<Result<void>> enqueue(
    String id,
    AuditEventDraft draft,
    DateTime at,
  ) async {
    if (failEnqueue) {
      return const Result.failure(DatabaseFailure('outbox unavailable'));
    }
    outbox.add(QueuedAuditEvent(id: id, draft: draft, createdAt: at, attempts: 0));
    return const Result.success(null);
  }

  @override
  Future<Result<List<QueuedAuditEvent>>> queued() async =>
      Result.success(List.of(outbox));

  @override
  Future<Result<void>> dequeue(String id) async {
    outbox.removeWhere((q) => q.id == id);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> markAttempt(String id, String error) async =>
      const Result.success(null);
}

AuditRecorder recorderFor(
  MemoryAuditRepository repo, {
  AuditActor? actor,
  StepClock? clock,
}) => AuditRecorder(
  repository: repo,
  actors: FixedActor(actor ?? AuditActor.localOperator('Ravi')),
  hasher: hasher,
  clock: clock ?? StepClock(),
  ids: CountingIds(),
);

AuditEventDraft draft({
  String type = 'product.updated',
  String entityId = 'p1',
  Map<String, Object?>? before,
  Map<String, Object?>? after,
  String? reason,
}) => AuditEventDraft(
  eventType: type,
  entityType: 'product',
  entityId: entityId,
  action: type.split('.').last,
  previousValues: before,
  newValues: after,
  reason: reason,
);
