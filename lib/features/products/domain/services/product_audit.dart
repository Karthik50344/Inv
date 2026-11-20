import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';

/// Builds the audit entries of product changes: which fields changed, from
/// what to what. The image path and free-text description are left out to
/// keep the log compact; money is recorded in minor units.
abstract final class ProductAudit {
  /// The audited values of [product].
  static Map<String, Object?> values(Product product) => {
    'sku': product.sku,
    'barcode': product.barcode,
    'name': product.name,
    'categoryId': product.categoryId,
    'unitId': product.unitId,
    'purchasePriceMinor': product.purchasePrice.minorUnits,
    'sellingPriceMinor': product.sellingPrice.minorUnits,
    'priceIncludesTax': product.priceIncludesTax,
    'taxRateId': product.taxRateId,
    'taxCategoryId': product.taxCategoryId,
    'taxOverrideId': product.taxOverrideId,
    'reorderLevelMilli': product.reorderLevel.milli,
    'archived': product.isArchived,
  };

  /// A product was created.
  static AuditEntry created(Product product, {required String id}) =>
      AuditEntry(
        id: id,
        entityType: 'product',
        entityId: product.id,
        action: 'created',
        summary: 'Product ${product.sku} "${product.name}" created.',
        occurredAt: product.createdAt,
        newValues: values(product),
      );

  /// A product changed; `null` when no audited field differs.
  static AuditEntry? updated(
    Product before,
    Product after, {
    required String id,
  }) {
    final old = values(before);
    final now = values(after);
    final previous = <String, Object?>{};
    final next = <String, Object?>{};
    for (final key in now.keys) {
      if (old[key] != now[key]) {
        previous[key] = old[key];
        next[key] = now[key];
      }
    }
    if (next.isEmpty) {
      return null;
    }
    final taxChanged = next.keys.any(
      (k) => k == 'taxRateId' || k == 'taxCategoryId' || k == 'taxOverrideId',
    );
    return AuditEntry(
      id: id,
      entityType: 'product',
      entityId: after.id,
      action: 'updated',
      summary:
          'Product ${after.sku} updated: ${next.keys.join(', ')}.',
      occurredAt: after.updatedAt,
      previousValues: previous,
      newValues: next,
      metadata: {if (taxChanged) 'taxTreatmentChanged': true},
    );
  }

  /// A product was archived or restored.
  static AuditEntry archivedChanged(
    Product product, {
    required String id,
    required bool archived,
    required DateTime at,
  }) => AuditEntry(
    id: id,
    entityType: 'product',
    entityId: product.id,
    action: archived ? 'archived' : 'restored',
    summary:
        'Product ${product.sku} "${product.name}" '
        '${archived ? 'archived' : 'restored'}.',
    occurredAt: at,
    previousValues: {'archived': !archived},
    newValues: {'archived': archived},
  );
}
