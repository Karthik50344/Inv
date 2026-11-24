import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_query.dart';

/// Read-only queries over the audit events, for the audit screens.
abstract interface class AuditQueryRepository {
  /// Events matching [filter], newest first.
  Future<Result<List<AuditEvent>>> search(AuditEventFilter filter);

  /// Dashboard numbers.
  Future<Result<AuditStats>> stats({int recentLimit = 10});

  /// One event, or `null`.
  Future<Result<AuditEvent?>> byId(String id);

  /// The other events of the same operation, in order.
  Future<Result<List<AuditEvent>>> byCorrelation(String correlationId);

  /// Distinct event types present, for the filter list.
  Future<Result<List<String>>> eventTypes();

  /// Distinct record types present, for the filter list.
  Future<Result<List<String>>> entityTypes();
}
