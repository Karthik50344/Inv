import 'package:drift/drift.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';

/// One SQL query that becomes one file of the export.
final class ExportQuery {
  /// Creates a query.
  const ExportQuery(this.path, this.sql, [this.variables = const []]);

  /// Path inside the package.
  final String path;

  /// The SELECT statement.
  final String sql;

  /// Values for the `?` placeholders, in order.
  final List<Variable<Object>> variables;
}

/// The SQL behind each dataset. Every statement only reads. Period filters
/// use the date of the *document* (invoice date, payment date, ...), and
/// lines, allocations and reversals follow their document.
abstract final class ExportQueries {
  static (String, List<Variable<Object>>) _range(String column, ExportPeriod p) {
    final parts = <String>[];
    final vars = <Variable<Object>>[];
    if (p.fromMs != null) {
      parts.add('$column >= ?');
      vars.add(Variable<int>(p.fromMs!));
    }
    if (p.toMsInclusive != null) {
      parts.add('$column <= ?');
      vars.add(Variable<int>(p.toMsInclusive!));
    }
    return (parts.isEmpty ? '1 = 1' : parts.join(' AND '), vars);
  }

  /// The queries of [dataset] for [period].
  static List<ExportQuery> forDataset(ExportDataset dataset, ExportPeriod period) {
    switch (dataset) {
      case ExportDataset.businessProfile:
        return const [
          ExportQuery('business_profile/business_profile.csv', 'SELECT * FROM business_profiles'),
        ];
      case ExportDataset.products:
        return const [
          ExportQuery('master_data/products.csv', 'SELECT * FROM products ORDER BY sku'),
        ];
      case ExportDataset.productClassifications:
        return const [
          ExportQuery(
            'master_data/product_classifications.csv',
            'SELECT c.*, p.sku AS product_sku FROM product_classifications c '
                'LEFT JOIN products p ON p.id = c.product_id '
                'ORDER BY p.sku, c.is_primary DESC, c.classification_system, '
                'c.classification_code',
          ),
        ];
      case ExportDataset.customers:
        return const [
          ExportQuery('master_data/customers.csv', 'SELECT * FROM customers ORDER BY name, id'),
        ];
      case ExportDataset.suppliers:
        return const [
          ExportQuery('master_data/suppliers.csv', 'SELECT * FROM suppliers ORDER BY name, id'),
        ];
      case ExportDataset.salesInvoices:
        return _documentWithLines(
          period,
          folder: 'sales',
          header: 'sales_invoices',
          lines: 'sales_invoice_items',
          dateColumn: 'invoice_date',
          orderBy: 'number',
        );
      case ExportDataset.purchaseInvoices:
        return _documentWithLines(
          period,
          folder: 'purchases',
          header: 'purchase_invoices',
          lines: 'purchase_invoice_items',
          dateColumn: 'invoice_date',
          orderBy: 'number',
        );
      case ExportDataset.salesReturns:
        return _documentWithLines(
          period,
          folder: 'sales',
          header: 'sales_returns',
          lines: 'sales_return_items',
          lineFk: 'return_id',
          dateColumn: 'return_date',
          orderBy: 'number',
        );
      case ExportDataset.purchaseReturns:
        return _documentWithLines(
          period,
          folder: 'purchases',
          header: 'purchase_returns',
          lines: 'purchase_return_items',
          lineFk: 'return_id',
          dateColumn: 'return_date',
          orderBy: 'number',
        );
      case ExportDataset.payments:
        {
        final (where, vars) = _range('p.payment_date', period);
        final (w2, v2) = _range('payment_date', period);
        return [
          ExportQuery('payments/payments.csv', 'SELECT * FROM payments WHERE $w2 ORDER BY payment_date, number', v2),
          ExportQuery(
            'payments/payment_allocations.csv',
            'SELECT a.* FROM payment_allocations a JOIN payments p ON p.id = a.payment_id '
                'WHERE $where ORDER BY p.payment_date, p.number, a.id',
            vars,
          ),
          ExportQuery(
            'payments/payment_reversals.csv',
            'SELECT r.* FROM payment_reversals r JOIN payments p ON p.id = r.payment_id '
                'WHERE $where ORDER BY r.reversed_at, r.id',
            vars,
          ),
        ];
        }
      case ExportDataset.expenses:
        {
        final (where, vars) = _range('expense_date', period);
        return [
          ExportQuery('expenses/expenses.csv', 'SELECT * FROM expenses WHERE $where ORDER BY expense_date, number', vars),
        ];
        }
      case ExportDataset.inventoryBalances:
        return const [
          ExportQuery(
            'inventory/inventory_balances.csv',
            'SELECT b.*, p.sku, p.name AS product_name FROM inventory_balances b '
                'LEFT JOIN products p ON p.id = b.product_id ORDER BY p.sku, b.product_id',
          ),
          ExportQuery(
            'inventory/inventory_valuation.csv',
            'SELECT p.sku, p.name AS product_name, b.quantity_on_hand_milli, '
                'b.inventory_value_minor, CASE WHEN b.quantity_on_hand_milli > 0 '
                'THEN b.inventory_value_minor * 1000 / b.quantity_on_hand_milli END '
                'AS average_unit_cost_minor FROM inventory_balances b '
                'LEFT JOIN products p ON p.id = b.product_id ORDER BY p.sku, b.product_id',
          ),
        ];
      case ExportDataset.stockMovements:
        {
        final (where, vars) = _range('occurred_at', period);
        return [
          ExportQuery(
            'inventory/stock_movements.csv',
            'SELECT m.*, p.sku FROM stock_movements m LEFT JOIN products p ON p.id = m.product_id '
                'WHERE ${where.replaceAll('occurred_at', 'm.occurred_at')} '
                'ORDER BY m.occurred_at, m.id',
            vars,
          ),
        ];
        }
      case ExportDataset.taxConfigurations:
        return const [
          ExportQuery(
            'taxation/tax_configurations.csv',
            'SELECT r.id AS rule_id, reg.name AS regime, pr.name AS profile, '
                'cat.code AS category_code, cat.name AS category, '
                'cat.default_tax_treatment, j.region_code, j.region_name, '
                'r.transaction_type, r.customer_tax_status, r.supply_type, '
                'r.supply_relation, r.calculation_method, r.is_stackable, '
                'r.effective_from, r.effective_until, r.priority, '
                'r.is_active AS rule_active, c.id AS component_id, '
                'c.name AS component, c.component_type, c.rate_basis_points, '
                'c.fixed_amount_minor, c.calculation_order, c.is_compound, '
                'c.is_recoverable, c.is_active AS component_active '
                'FROM tax_rules r '
                'JOIN tax_profiles pr ON pr.id = r.tax_profile_id '
                'JOIN tax_regimes reg ON reg.id = pr.regime_id '
                'JOIN tax_categories cat ON cat.id = r.tax_category_id '
                'LEFT JOIN tax_jurisdictions j ON j.id = r.jurisdiction_id '
                'LEFT JOIN tax_components c ON c.tax_rule_id = r.id '
                'ORDER BY reg.name, pr.name, cat.code, r.id, c.calculation_order',
          ),
          ExportQuery('taxation/tax_categories.csv', 'SELECT * FROM tax_categories ORDER BY code'),
          ExportQuery('taxation/tax_overrides.csv', 'SELECT * FROM tax_overrides ORDER BY name'),
          ExportQuery('taxation/tax_rates_legacy.csv', 'SELECT * FROM tax_rates ORDER BY name'),
        ];
      case ExportDataset.taxSummaries:
        return _taxSummaries(period);
      case ExportDataset.hsnSummaries:
        return _hsnSummaries(period);
      case ExportDataset.auditTrail:
        {
        final (where, vars) = _range('occurred_at_utc', period);
        final (w2, v2) = _range('occurred_at', period);
        return [
          ExportQuery('audit/audit_events.csv', 'SELECT * FROM audit_events WHERE $where ORDER BY seq', vars),
          ExportQuery('audit/legacy_audit_logs.csv', 'SELECT * FROM audit_logs WHERE $w2 ORDER BY occurred_at, id', v2),
        ];
        }
      case ExportDataset.attachments:
      case ExportDataset.invoicePdfs:
        return const [];
    }
  }

  /// Rows listing the attachment files created in [period].
  static ExportQuery attachmentRefs(ExportPeriod period) {
    final (where, vars) = _range('created_at', period);
    return ExportQuery(
      'attachments',
      'SELECT id, owner_type, owner_id, file_name, stored_path FROM attachments '
          'WHERE $where ORDER BY created_at, id',
      vars,
    );
  }

  /// Rows listing posted and voided sales invoices in [period].
  static ExportQuery invoiceRefs(ExportPeriod period) {
    final (where, vars) = _range('invoice_date', period);
    return ExportQuery(
      'invoices',
      "SELECT id, number FROM sales_invoices WHERE status IN ('posted', 'voided') "
          'AND number IS NOT NULL AND $where ORDER BY number',
      vars,
    );
  }

  static List<ExportQuery> _documentWithLines(
    ExportPeriod period, {
    required String folder,
    required String header,
    required String lines,
    required String dateColumn,
    required String orderBy,
    String lineFk = 'invoice_id',
  }) {
    final (where, vars) = _range(dateColumn, period);
    final (hw, hv) = _range('h.$dateColumn', period);
    return [
      ExportQuery('$folder/$header.csv', 'SELECT * FROM $header WHERE $where ORDER BY $dateColumn, $orderBy', vars),
      ExportQuery(
        '$folder/$lines.csv',
        'SELECT i.* FROM $lines i JOIN $header h ON h.id = i.$lineFk '
            'WHERE $hw ORDER BY h.$dateColumn, h.$orderBy, i.line_no',
        hv,
      ),
    ];
  }

  static List<ExportQuery> _taxSummaries(ExportPeriod period) {
    String posted(String h) => "$h.status = 'posted'";
    final (r1, v) = _range('h.invoice_date', period);
    final all = <Variable<Object>>[];
    String part(String doc, String items, String head, {required bool components}) {
      all.addAll(v);
      if (components) {
        return "SELECT '$doc' AS document_type, c.name AS component, "
            'c.component_type AS component_type, c.rate_basis_points AS rate_bp, '
            'COUNT(*) AS lines, SUM(c.taxable_minor) AS taxable_minor, '
            'SUM(c.amount_minor) AS tax_minor '
            'FROM invoice_item_tax_components c '
            "JOIN $items i ON c.document_type = '$doc' AND i.id = c.item_id "
            'JOIN $head h ON h.id = i.invoice_id '
            'WHERE ${posted('h')} AND $r1 '
            'GROUP BY c.name, c.component_type, c.rate_basis_points';
      }
      return "SELECT '$doc', COALESCE(i.tax_name, '(no tax)'), 'legacy_single_rate', "
          'i.tax_rate_bp, COUNT(*), SUM(i.net_minor), SUM(i.tax_minor) '
          'FROM $items i JOIN $head h ON h.id = i.invoice_id '
          'WHERE ${posted('h')} AND $r1 AND i.tax_snapshot_json IS NULL '
          'GROUP BY i.tax_name, i.tax_rate_bp';
    }

    final summary = [
      part('sales', 'sales_invoice_items', 'sales_invoices', components: true),
      part('purchase', 'purchase_invoice_items', 'purchase_invoices', components: true),
      part('sales', 'sales_invoice_items', 'sales_invoices', components: false),
      part('purchase', 'purchase_invoice_items', 'purchase_invoices', components: false),
    ].join(' UNION ALL ');

    final treatmentVars = <Variable<Object>>[];
    String treatment(String doc, String items, String head) {
      treatmentVars.addAll(v);
      return "SELECT '$doc' AS document_type, "
          "COALESCE(i.tax_treatment, 'legacy_single_rate') AS treatment, "
          'COUNT(*) AS lines, SUM(i.net_minor) AS taxable_minor, '
          'SUM(i.tax_minor) AS tax_minor '
          'FROM $items i JOIN $head h ON h.id = i.invoice_id '
          'WHERE ${posted('h')} AND $r1 GROUP BY 2';
    }

    final treatments = [
      treatment('sales', 'sales_invoice_items', 'sales_invoices'),
      treatment('purchase', 'purchase_invoice_items', 'purchase_invoices'),
    ].join(' UNION ALL ');

    final detailVars = <Variable<Object>>[...v, ...v];
    final detail =
        'SELECT c.*, h.number AS document_number, h.invoice_date AS document_date '
        'FROM invoice_item_tax_components c '
        "JOIN sales_invoice_items i ON c.document_type = 'sales' AND i.id = c.item_id "
        'JOIN sales_invoices h ON h.id = i.invoice_id WHERE $r1 '
        'UNION ALL '
        'SELECT c.*, h.number, h.invoice_date '
        'FROM invoice_item_tax_components c '
        "JOIN purchase_invoice_items i ON c.document_type = 'purchase' AND i.id = c.item_id "
        'JOIN purchase_invoices h ON h.id = i.invoice_id WHERE $r1';

    return [
      ExportQuery(
        'taxation/tax_summaries.csv',
        'SELECT * FROM ($summary) ORDER BY 1, 2, 4',
        all,
      ),
      ExportQuery(
        'taxation/treatment_summaries.csv',
        'SELECT * FROM ($treatments) ORDER BY 1, 2',
        treatmentVars,
      ),
      ExportQuery(
        'taxation/invoice_tax_components.csv',
        'SELECT * FROM ($detail) ORDER BY document_date, document_number, item_id, component_no',
        detailVars,
      ),
    ];
  }

  static List<ExportQuery> _hsnSummaries(ExportPeriod period) {
    final (r1, v) = _range('h.invoice_date', period);
    String part(String doc, String items, String head) =>
        "SELECT '$doc' AS document_type, "
        "COALESCE(i.classification_system, '') AS classification_system, "
        "COALESCE(i.classification_code, '(none)') AS classification_code, "
        'MAX(i.classification_description) AS description, i.unit_symbol AS unit, '
        'COUNT(*) AS lines, SUM(i.quantity_milli) AS quantity_milli, '
        'SUM(i.net_minor) AS taxable_minor, SUM(i.tax_minor) AS tax_minor, '
        'SUM(i.total_minor) AS total_minor '
        'FROM $items i JOIN $head h ON h.id = i.invoice_id '
        "WHERE h.status = 'posted' AND $r1 "
        'GROUP BY i.classification_system, i.classification_code, i.unit_symbol';
    return [
      ExportQuery(
        'taxation/hsn_summaries.csv',
        'SELECT * FROM (${part('sales', 'sales_invoice_items', 'sales_invoices')} '
            'UNION ALL ${part('purchase', 'purchase_invoice_items', 'purchase_invoices')}) '
            'ORDER BY 1, 2, 3, 5',
        [...v, ...v],
      ),
    ];
  }
}
