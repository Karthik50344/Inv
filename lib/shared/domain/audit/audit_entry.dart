import 'package:equatable/equatable.dart';

/// An append-only record of a business action for traceability.
///
/// Summaries must not contain sensitive business data beyond what is needed
/// to understand the action.
final class AuditEntry extends Equatable {
  /// Creates an entry.
  const AuditEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.summary,
    required this.occurredAt,
  });

  /// Unique id.
  final String id;

  /// Kind of entity affected, e.g. `stock`.
  final String entityType;

  /// Id of the affected entity.
  final String entityId;

  /// Short action name, e.g. `adjustment_in`.
  final String action;

  /// Human readable summary.
  final String summary;

  /// When the action happened (UTC).
  final DateTime occurredAt;

  @override
  List<Object?> get props => [
    id,
    entityType,
    entityId,
    action,
    summary,
    occurredAt,
  ];
}
