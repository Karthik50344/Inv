import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';

/// An event waiting in the outbox.
final class QueuedAuditEvent extends Equatable {
  /// Creates a queue entry.
  const QueuedAuditEvent({
    required this.id,
    required this.draft,
    required this.createdAt,
    required this.attempts,
  });

  /// Outbox row id.
  final String id;

  /// The event to record (actor and time already fixed).
  final AuditEventDraft draft;

  /// When it was queued.
  final DateTime createdAt;

  /// Failed flush attempts so far.
  final int attempts;

  @override
  List<Object?> get props => [id, draft, createdAt, attempts];
}

/// Append-only storage of audit events. There is deliberately no update or
/// delete operation.
abstract interface class AuditEventRepository {
  /// Appends one event to the chain inside a single database transaction:
  /// reads the hash of the last event, builds the event with [seal], and
  /// inserts it. When the chain is empty and [genesis] is given, the
  /// genesis event is inserted first.
  ///
  /// Called inside a business transaction, the event commits or rolls back
  /// with it.
  Future<Result<AuditEvent>> appendChained(
    AuditEvent Function(String previousHash) seal, {
    AuditEvent Function(String previousHash)? genesis,
  });

  /// Number of rows in the legacy `audit_logs` table (recorded before the
  /// hash chain existed).
  Future<Result<int>> legacyLogCount();

  /// Events with a sequence greater than [afterSequence], ascending.
  Future<Result<List<AuditEvent>>> page({
    int afterSequence = 0,
    int limit = 500,
  });

  /// The newest event, or `null` when the chain is empty.
  Future<Result<AuditEvent?>> latest();

  /// Events of one record, newest first.
  Future<Result<List<AuditEvent>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  });

  /// Queues [draft] for a later retry.
  Future<Result<void>> enqueue(String id, AuditEventDraft draft, DateTime at);

  /// Queued events, oldest first.
  Future<Result<List<QueuedAuditEvent>>> queued();

  /// Removes a flushed entry.
  Future<Result<void>> dequeue(String id);

  /// Counts a failed attempt on [id].
  Future<Result<void>> markAttempt(String id, String error);
}
