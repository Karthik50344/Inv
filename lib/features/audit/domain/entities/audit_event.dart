import 'package:equatable/equatable.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';

/// Hash stored as the "previous hash" of the first event of the chain.
final String kAuditGenesisHash = '0' * 64;

/// Version of the field set that is hashed. Bump it when the hashed fields
/// change; old events keep verifying under their own version.
const int kAuditSchemaVersion = 1;

/// One immutable, hash-chained record of something that happened.
///
/// Each event stores the hash of the event before it and its own hash over
/// all of its fields, so editing, removing or reordering an event breaks the
/// chain from that point on. A chain kept in the same local database is
/// tamper-*evident*, not tamper-proof: see `docs/security/audit_trail.md`.
final class AuditEvent extends Equatable {
  const AuditEvent._({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actor,
    required this.occurredAtUtc,
    required this.source,
    required this.correlationId,
    required this.previousEventHash,
    required this.eventHash,
    required this.schemaVersion,
    this.sequence,
    this.reason,
    this.previousValues,
    this.newValues,
    this.metadata,
  });

  /// Builds and seals a new event: computes [eventHash] over every field and
  /// [previousEventHash].
  factory AuditEvent.seal({
    required String id,
    required String eventType,
    required String entityType,
    required String entityId,
    required String action,
    required AuditActor actor,
    required DateTime occurredAtUtc,
    required String source,
    required String correlationId,
    required String previousEventHash,
    required AuditHasher hasher,
    String? reason,
    Map<String, Object?>? previousValues,
    Map<String, Object?>? newValues,
    Map<String, Object?>? metadata,
    int schemaVersion = kAuditSchemaVersion,
  }) {
    final time = DateTime.fromMillisecondsSinceEpoch(
      occurredAtUtc.millisecondsSinceEpoch,
      isUtc: true,
    );
    final unsigned = AuditEvent._(
      id: id,
      eventType: eventType,
      entityType: entityType,
      entityId: entityId,
      action: action,
      actor: actor,
      occurredAtUtc: time,
      source: source,
      correlationId: correlationId,
      previousEventHash: previousEventHash,
      eventHash: '',
      schemaVersion: schemaVersion,
      reason: reason,
      previousValues: _frozen(previousValues),
      newValues: _frozen(newValues),
      metadata: _frozen(metadata),
    );
    return unsigned.withHash(unsigned.computeHash(hasher));
  }

  /// Rebuilds an event read from storage. The hash is taken as stored; use
  /// [isHashValid] to check it.
  factory AuditEvent.stored({
    required String id,
    required String eventType,
    required String entityType,
    required String entityId,
    required String action,
    required AuditActor actor,
    required DateTime occurredAtUtc,
    required String source,
    required String correlationId,
    required String previousEventHash,
    required String eventHash,
    required int schemaVersion,
    int? sequence,
    String? reason,
    Map<String, Object?>? previousValues,
    Map<String, Object?>? newValues,
    Map<String, Object?>? metadata,
  }) => AuditEvent._(
    id: id,
    eventType: eventType,
    entityType: entityType,
    entityId: entityId,
    action: action,
    actor: actor,
    occurredAtUtc: occurredAtUtc,
    source: source,
    correlationId: correlationId,
    previousEventHash: previousEventHash,
    eventHash: eventHash,
    schemaVersion: schemaVersion,
    sequence: sequence,
    reason: reason,
    previousValues: _frozen(previousValues),
    newValues: _frozen(newValues),
    metadata: _frozen(metadata),
  );

  static Map<String, Object?>? _frozen(Map<String, Object?>? values) =>
      values == null ? null : Map.unmodifiable(values);

  /// Unique identifier.
  final String id;

  /// Position in the chain, assigned by the database (not hashed).
  final int? sequence;

  /// What happened, for example `sales_invoice.voided`.
  final String eventType;

  /// Kind of record affected.
  final String entityType;

  /// The record affected.
  final String entityId;

  /// Verb: `created`, `updated`, `voided`, ...
  final String action;

  /// Who or what did it.
  final AuditActor actor;

  /// When it happened (UTC, millisecond precision).
  final DateTime occurredAtUtc;

  /// Why it happened, when the user gave a reason.
  final String? reason;

  /// Where it came from (`app`, `system`, `import`, ...).
  final String source;

  /// Groups events of one operation.
  final String correlationId;

  /// Values before the change.
  final Map<String, Object?>? previousValues;

  /// Values after the change.
  final Map<String, Object?>? newValues;

  /// Anything else worth keeping (documents involved, summary text).
  final Map<String, Object?>? metadata;

  /// Hash of the event before this one ([kAuditGenesisHash] for the first).
  final String previousEventHash;

  /// Hash over every field of this event.
  final String eventHash;

  /// Version of the hashed field set.
  final int schemaVersion;

  /// The exact map that is canonicalised and hashed.
  Map<String, Object?> hashPayload() => {
    'v': schemaVersion,
    'id': id,
    'eventType': eventType,
    'entityType': entityType,
    'entityId': entityId,
    'action': action,
    'actorType': actor.type.code,
    'actorId': actor.id,
    'actorDisplayName': actor.displayName,
    'occurredAtUtc': occurredAtUtc.millisecondsSinceEpoch,
    'reason': reason,
    'source': source,
    'correlationId': correlationId,
    'previousValues': previousValues,
    'newValues': newValues,
    'metadata': metadata,
    'previousEventHash': previousEventHash,
  };

  /// Recomputes the hash from the current field values.
  String computeHash(AuditHasher hasher) =>
      hasher.sha256Hex(AuditCanonical.encode(hashPayload()));

  /// Whether the stored hash matches the fields.
  bool isHashValid(AuditHasher hasher) => computeHash(hasher) == eventHash;

  /// A copy carrying [hash].
  AuditEvent withHash(String hash) => AuditEvent._(
    id: id,
    sequence: sequence,
    eventType: eventType,
    entityType: entityType,
    entityId: entityId,
    action: action,
    actor: actor,
    occurredAtUtc: occurredAtUtc,
    reason: reason,
    source: source,
    correlationId: correlationId,
    previousValues: previousValues,
    newValues: newValues,
    metadata: metadata,
    previousEventHash: previousEventHash,
    eventHash: hash,
    schemaVersion: schemaVersion,
  );

  @override
  List<Object?> get props => [
    id,
    sequence,
    eventType,
    entityType,
    entityId,
    action,
    actor,
    occurredAtUtc,
    reason,
    source,
    correlationId,
    previousValues,
    newValues,
    metadata,
    previousEventHash,
    eventHash,
    schemaVersion,
  ];
}
