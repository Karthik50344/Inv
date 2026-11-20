import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/audit_correlation.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_event_repository.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';

/// Records audit events.
///
/// Two ways to record, chosen by whether the business operation shares a
/// database transaction with the audit write:
///
/// - [record] is **fail-closed**. Call it inside the same transaction as the
///   business change. If it fails, the caller returns the failure, the
///   transaction rolls back and the operation is not committed: a business
///   change never exists without its audit event.
/// - [recordOrQueue] is for work that cannot share a transaction (a backup
///   file already written, an export already shared). If the audit write
///   fails the event is parked in a durable outbox and retried by
///   [flushOutbox] (before every later write and at start-up). Only if even
///   the outbox write fails does the caller get a failure to show the user.
final class AuditRecorder {
  /// Creates a recorder.
  const AuditRecorder({
    required AuditEventRepository repository,
    required AuditActorProvider actors,
    required AuditHasher hasher,
    required Clock clock,
    required IdGenerator ids,
  }) : _repository = repository,
       _actors = actors,
       _hasher = hasher,
       _clock = clock,
       _ids = ids;

  final AuditEventRepository _repository;
  final AuditActorProvider _actors;
  final AuditHasher _hasher;
  final Clock _clock;
  final IdGenerator _ids;

  /// Appends [draft] to the chain (fail-closed, see class documentation).
  Future<Result<AuditEvent>> record(AuditEventDraft draft) async {
    final AuditEventDraft resolved;
    try {
      resolved = await _resolve(draft);
    } on Object catch (error, stack) {
      return Result.failure(
        AuditFailure(
          'The audit event could not be prepared.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
    return _append(resolved);
  }

  /// Records [draft], or parks it in the outbox if the audit write fails.
  Future<Result<void>> recordOrQueue(AuditEventDraft draft) async {
    final AuditEventDraft resolved;
    try {
      await flushOutbox();
      resolved = await _resolve(draft);
    } on Object catch (error, stack) {
      return Result.failure(
        AuditFailure(
          'The audit event could not be prepared.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
    final appended = await _append(resolved);
    if (appended.isSuccess) {
      return const Result.success(null);
    }
    final queued = await _repository.enqueue(
      _ids.newId(),
      resolved,
      _clock.now(),
    );
    return queued.isSuccess
        ? const Result.success(null)
        : Result.failure(
            AuditFailure(
              'The action was done but could not be recorded in the audit '
              'trail. Please try again.',
              cause: queued.failureOrNull,
            ),
          );
  }

  /// Retries queued events in order. Stops at the first failure so order is
  /// kept. Returns how many were written.
  Future<Result<int>> flushOutbox() async {
    final loaded = await _repository.queued();
    final entries = loaded.valueOrNull;
    if (entries == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    var written = 0;
    for (final entry in entries) {
      final appended = await _append(entry.draft);
      if (appended.isFailure) {
        await _repository.markAttempt(
          entry.id,
          appended.failureOrNull!.message,
        );
        break;
      }
      await _repository.dequeue(entry.id);
      written++;
    }
    return Result.success(written);
  }

  Future<AuditEventDraft> _resolve(AuditEventDraft draft) async {
    // Fail early, outside any database transaction, on values that cannot
    // be serialised canonically.
    AuditCanonical.encode(draft.previousValues);
    AuditCanonical.encode(draft.newValues);
    AuditCanonical.encode(draft.metadata);
    final actor = draft.actor ?? await _actors.current();
    final id = _ids.newId();
    return draft.resolved(
      actor: actor,
      occurredAtUtc: _clock.now().toUtc(),
      correlationId: AuditCorrelation.current ?? id,
    );
  }

  Future<Result<AuditEvent>> _append(AuditEventDraft draft) async {
    final legacy = await _repository.legacyLogCount();
    final legacyCount = legacy.valueOrNull ?? 0;
    final at = draft.occurredAtUtc ?? _clock.now().toUtc();
    final correlation = draft.correlationId ?? _ids.newId();
    final id = _ids.newId();
    try {
      return await _repository.appendChained(
        (previous) => AuditEvent.seal(
          id: id,
          eventType: draft.eventType,
          entityType: draft.entityType,
          entityId: draft.entityId,
          action: draft.action,
          actor: draft.actor ?? AuditActor.device,
          occurredAtUtc: at,
          reason: draft.reason,
          source: draft.source,
          correlationId: correlation,
          previousValues: draft.previousValues,
          newValues: draft.newValues,
          metadata: draft.metadata,
          previousEventHash: previous,
          hasher: _hasher,
        ),
        genesis: (previous) => AuditEvent.seal(
          id: _ids.newId(),
          eventType: 'audit.chain_started',
          entityType: 'audit',
          entityId: 'chain',
          action: 'chain_started',
          actor: AuditActor.system,
          occurredAtUtc: at,
          source: 'system',
          correlationId: correlation,
          metadata: {
            'legacyLogCount': legacyCount,
            'note':
                'Entries recorded before this event are in the legacy audit '
                'log and are not covered by the hash chain.',
          },
          previousEventHash: previous,
          hasher: _hasher,
        ),
      );
    } on ArgumentError catch (error, stack) {
      return Result.failure(
        AuditFailure(
          'The audit event contains a value that cannot be recorded.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }
}
