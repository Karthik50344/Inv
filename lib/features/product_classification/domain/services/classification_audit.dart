import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';

/// Audit entries for classification changes (record type
/// `product_classification`, the record id is the classification's id and
/// `metadata.productId` links it to its product).
abstract final class ClassificationAudit {
  /// The audited values of [c].
  static Map<String, Object?> values(ProductClassification c) => {
    'system': c.system.code,
    'code': c.code,
    'description': c.description,
    'countryCode': c.countryCode,
    'type': c.type.code,
    'isPrimary': c.isPrimary,
  };

  /// [action] is `added`, `updated`, `removed` or `primary_changed`.
  static AuditEntry entry({
    required String id,
    required String action,
    required ProductClassification classification,
    required DateTime at,
    ProductClassification? before,
  }) => AuditEntry(
    id: id,
    entityType: 'product_classification',
    entityId: classification.id,
    action: action,
    summary:
        'Classification ${classification.system.displayName} '
        '${classification.code} $action.',
    occurredAt: at,
    previousValues: before == null ? null : values(before),
    newValues: action == 'removed' ? null : values(classification),
    metadata: {'productId': classification.productId},
  );
}
