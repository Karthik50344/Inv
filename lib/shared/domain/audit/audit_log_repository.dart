import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';

/// Persistence contract for the audit log (append-only).
abstract interface class AuditLogRepository {
  /// Appends [entry]. Call inside the same transaction as the change it
  /// describes.
  Future<Result<void>> record(AuditEntry entry);

  /// Most recent entries for an entity, newest first.
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  });
}
