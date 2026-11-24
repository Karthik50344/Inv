import 'package:equatable/equatable.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';

/// Search criteria of the audit log screen. Every field is optional; all
/// given criteria must match.
final class AuditEventFilter extends Equatable {
  /// Creates a filter.
  const AuditEventFilter({
    this.search = '',
    this.from,
    this.to,
    this.eventType,
    this.entityType,
    this.actor = '',
    this.reference = '',
    this.limit = 50,
    this.offset = 0,
  });

  /// Free text: matches event type, record id, reason, actor and details.
  final String search;

  /// First day (inclusive).
  final DateTime? from;

  /// Last day (inclusive).
  final DateTime? to;

  /// Exact event type, for example `sales_invoice.voided`.
  final String? eventType;

  /// Exact record type, for example `sales_invoice`.
  final String? entityType;

  /// Part of the actor name.
  final String actor;

  /// Part of a document or reference number (found in the event summary or
  /// the record id).
  final String reference;

  /// Page size.
  final int limit;

  /// Rows to skip.
  final int offset;

  /// The same filter for the next page.
  AuditEventFilter nextPage() => AuditEventFilter(
    search: search,
    from: from,
    to: to,
    eventType: eventType,
    entityType: entityType,
    actor: actor,
    reference: reference,
    limit: limit,
    offset: offset + limit,
  );

  @override
  List<Object?> get props => [
    search,
    from,
    to,
    eventType,
    entityType,
    actor,
    reference,
    limit,
    offset,
  ];
}

/// Numbers for the audit dashboard.
final class AuditStats extends Equatable {
  /// Creates the stats.
  const AuditStats({
    required this.totalEvents,
    required this.byType,
    required this.cancelledDocuments,
    required this.reversedPayments,
    required this.taxConfigurationChanges,
    required this.stockAdjustments,
    required this.dataExports,
    required this.recent,
  });

  /// All events.
  final int totalEvents;

  /// Events per event type, most frequent first.
  final Map<String, int> byType;

  /// Voided or cancelled documents.
  final int cancelledDocuments;

  /// Reversed payments.
  final int reversedPayments;

  /// Changes to tax rates, categories, rules or components.
  final int taxConfigurationChanges;

  /// Stock events (opening stock, adjustments, repairs).
  final int stockAdjustments;

  /// Auditor exports created.
  final int dataExports;

  /// The newest events.
  final List<AuditEvent> recent;

  @override
  List<Object?> get props => [
    totalEvents,
    byType,
    cancelledDocuments,
    reversedPayments,
    taxConfigurationChanges,
    stockAdjustments,
    dataExports,
    recent,
  ];
}
