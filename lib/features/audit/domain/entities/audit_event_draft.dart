import 'package:equatable/equatable.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';

/// What a use case reports; the recorder fills in the rest (id, actor,
/// time, correlation id, hashes).
///
/// Never put passwords, tokens or other secrets in a draft. Values are
/// stored as readable JSON.
final class AuditEventDraft extends Equatable {
  /// Creates a draft.
  const AuditEventDraft({
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.reason,
    this.source = 'app',
    this.correlationId,
    this.previousValues,
    this.newValues,
    this.metadata,
    this.actor,
    this.occurredAtUtc,
  });

  /// Reads a draft written by [toJson] (used by the outbox).
  factory AuditEventDraft.fromJson(Map<String, Object?> json) =>
      AuditEventDraft(
        eventType: json['eventType']! as String,
        entityType: json['entityType']! as String,
        entityId: json['entityId']! as String,
        action: json['action']! as String,
        reason: json['reason'] as String?,
        source: json['source']! as String,
        correlationId: json['correlationId'] as String?,
        previousValues: _map(json['previousValues']),
        newValues: _map(json['newValues']),
        metadata: _map(json['metadata']),
        actor: json['actorType'] == null
            ? null
            : AuditActor(
                type: AuditActorType.parse(json['actorType']! as String),
                id: json['actorId'] as String?,
                displayName: json['actorDisplayName']! as String,
              ),
        occurredAtUtc: json['occurredAtMs'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                json['occurredAtMs']! as int,
                isUtc: true,
              ),
      );

  static Map<String, Object?>? _map(Object? value) => value == null
      ? null
      : (value as Map<Object?, Object?>).cast<String, Object?>();

  /// What happened, for example `product.updated`.
  final String eventType;

  /// Kind of record affected.
  final String entityType;

  /// The record affected.
  final String entityId;

  /// Verb.
  final String action;

  /// Why, when the user gave a reason.
  final String? reason;

  /// Origin of the action.
  final String source;

  /// Overrides the running operation's correlation id.
  final String? correlationId;

  /// Values before the change.
  final Map<String, Object?>? previousValues;

  /// Values after the change.
  final Map<String, Object?>? newValues;

  /// Extra context.
  final Map<String, Object?>? metadata;

  /// Overrides the current actor.
  final AuditActor? actor;

  /// Overrides the current time (kept when an event waits in the outbox).
  final DateTime? occurredAtUtc;

  /// A copy with actor, time and correlation id fixed.
  AuditEventDraft resolved({
    required AuditActor actor,
    required DateTime occurredAtUtc,
    required String correlationId,
  }) => AuditEventDraft(
    eventType: eventType,
    entityType: entityType,
    entityId: entityId,
    action: action,
    reason: reason,
    source: source,
    correlationId: this.correlationId ?? correlationId,
    previousValues: previousValues,
    newValues: newValues,
    metadata: metadata,
    actor: this.actor ?? actor,
    occurredAtUtc: this.occurredAtUtc ?? occurredAtUtc,
  );

  /// JSON map for the outbox.
  Map<String, Object?> toJson() => {
    'eventType': eventType,
    'entityType': entityType,
    'entityId': entityId,
    'action': action,
    'reason': reason,
    'source': source,
    'correlationId': correlationId,
    'previousValues': previousValues,
    'newValues': newValues,
    'metadata': metadata,
    'actorType': actor?.type.code,
    'actorId': actor?.id,
    'actorDisplayName': actor?.displayName,
    'occurredAtMs': occurredAtUtc?.millisecondsSinceEpoch,
  };

  @override
  List<Object?> get props => [
    eventType,
    entityType,
    entityId,
    action,
    reason,
    source,
    correlationId,
    previousValues,
    newValues,
    metadata,
    actor,
    occurredAtUtc,
  ];
}
