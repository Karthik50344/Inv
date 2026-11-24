import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';

/// Plain-language names for audit events, so the screens never show codes
/// such as `sales_invoice.voided` to the business owner.
abstract final class AuditLabels {
  static const Map<String, String> _entities = {
    'sales_invoice': 'Sales invoice',
    'purchase_invoice': 'Purchase invoice',
    'sales_return': 'Sales return',
    'purchase_return': 'Purchase return',
    'payment': 'Payment',
    'expense': 'Expense',
    'stock': 'Stock',
    'product': 'Product',
    'product_classification': 'Product classification',
    'category': 'Category',
    'unit': 'Unit',
    'customer': 'Customer',
    'supplier': 'Supplier',
    'tax_rate': 'Tax rate',
    'settings': 'Settings',
    'data_export': 'Export',
    'audit': 'Audit trail',
  };

  /// A readable name for a record type.
  static String entity(String entityType) =>
      _entities[entityType] ?? _words(entityType);

  /// A readable name for an action (`primary_changed` -> `Primary changed`).
  static String action(String action) => _capital(_words(action));

  /// `Sales invoice voided`.
  static String title(AuditEvent event) =>
      '${entity(event.entityType)} ${_words(event.action)}';

  /// The one-line description recorded with the event, if any.
  static String? summary(AuditEvent event) {
    final text = event.metadata?['summary'];
    return text is String && text.isNotEmpty ? text : null;
  }

  /// Who did it, with a plain note that names are not verified.
  static String actor(AuditActor actor) => switch (actor.type) {
    AuditActorType.localOperator => '${actor.displayName} (local operator, not verified)',
    AuditActorType.device => 'This device (no person identified)',
    AuditActorType.system => 'System',
    AuditActorType.authenticatedUser => actor.displayName,
  };

  /// A short actor name for lists.
  static String actorShort(AuditActor actor) => actor.displayName;

  /// `sellingPriceMinor` -> `Selling price minor`.
  static String field(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return _capital(spaced.replaceAll('_', ' ').toLowerCase());
  }

  /// A value for the before/after view.
  static String value(Object? value) {
    if (value == null) {
      return 'Not set';
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    if (value is Iterable) {
      return value.map(AuditLabels.value).join(', ');
    }
    if (value is Map) {
      return value.entries.map((e) => '${field('${e.key}')}: ${AuditLabels.value(e.value)}').join('; ');
    }
    return '$value';
  }

  static String _words(String code) => code.replaceAll('_', ' ').replaceAll('.', ' ');

  static String _capital(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
