/// SQL that Drift's table DSL cannot express (partial/expression indexes and
/// triggers). Executed by `AppDatabase` right after the tables are created.
///
/// Because these statements are not part of the generated schema, any change
/// here needs a matching migration step.
const List<String> kSchemaExtraStatements = [
  // Category names are unique (case-insensitive) among active categories.
  'CREATE UNIQUE INDEX uq_categories_name_active '
      'ON categories (lower(name)) WHERE archived_at IS NULL',
  // Barcodes are optional but unique when present.
  'CREATE UNIQUE INDEX uq_products_barcode '
      'ON products (barcode) WHERE barcode IS NOT NULL',
  // Idempotency: one movement of a given type per source document line.
  'CREATE UNIQUE INDEX uq_stock_movements_source ON stock_movements '
      '(source_type, source_id, source_line_id, movement_type) '
      'WHERE source_id IS NOT NULL',
  // The stock ledger is append-only.
  'CREATE TRIGGER trg_stock_movements_no_update '
      'BEFORE UPDATE ON stock_movements '
      "BEGIN SELECT RAISE(ABORT, 'stock_movements is append-only'); END",
  'CREATE TRIGGER trg_stock_movements_no_delete '
      'BEFORE DELETE ON stock_movements '
      "BEGIN SELECT RAISE(ABORT, 'stock_movements is append-only'); END",
];

/// Extra SQL introduced by schema version 2 (customers and suppliers).
/// Runs on fresh installs and as part of the 1 -> 2 upgrade.
const List<String> kSchemaExtraStatementsV2 = [
  'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers (name)',
  'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers (name)',
];

/// Extra SQL introduced by schema version 3 (audit log). Runs on fresh
/// installs and as part of the 2 -> 3 upgrade.
const List<String> kSchemaExtraStatementsV3 = [
  'CREATE TRIGGER IF NOT EXISTS trg_audit_logs_no_update '
      'BEFORE UPDATE ON audit_logs '
      "BEGIN SELECT RAISE(ABORT, 'audit_logs is append-only'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_audit_logs_no_delete '
      'BEFORE DELETE ON audit_logs '
      "BEGIN SELECT RAISE(ABORT, 'audit_logs is append-only'); END",
];

/// Extra SQL introduced by schema version 4 (purchases). Runs on fresh
/// installs and as part of the 3 -> 4 upgrade; every statement is
/// idempotent.
const List<String> kSchemaExtraStatementsV4 = [
  // Index the @TableIndex of audit_logs created in v3 never reached on
  // upgraded databases (Migrator.createTable does not create indexes).
  'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity '
      'ON audit_logs (entity_type, entity_id, occurred_at)',
  // Document numbers are unique once assigned.
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_purchase_invoices_number '
      'ON purchase_invoices (number) WHERE number IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier_date '
      'ON purchase_invoices (supplier_id, invoice_date)',
  'CREATE INDEX IF NOT EXISTS idx_purchase_invoices_status '
      'ON purchase_invoices (status)',
  'CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice '
      'ON purchase_invoice_items (invoice_id)',
  'CREATE INDEX IF NOT EXISTS idx_purchase_items_product '
      'ON purchase_invoice_items (product_id)',
  // Posted, voided and cancelled invoices are immutable. The one allowed
  // change is posted -> voided, which must leave every financial and
  // identifying column untouched.
  'CREATE TRIGGER IF NOT EXISTS trg_purchase_invoices_protect '
      'BEFORE UPDATE ON purchase_invoices '
      "WHEN OLD.status IN ('posted','voided','cancelled') AND NOT ("
      "OLD.status = 'posted' AND NEW.status = 'voided' "
      'AND NEW.number IS OLD.number '
      'AND NEW.supplier_id = OLD.supplier_id '
      'AND NEW.supplier_name = OLD.supplier_name '
      'AND NEW.invoice_date = OLD.invoice_date '
      'AND NEW.currency_code = OLD.currency_code '
      'AND NEW.decimal_places = OLD.decimal_places '
      'AND NEW.subtotal_minor = OLD.subtotal_minor '
      'AND NEW.discount_total_minor = OLD.discount_total_minor '
      'AND NEW.net_total_minor = OLD.net_total_minor '
      'AND NEW.tax_total_minor = OLD.tax_total_minor '
      'AND NEW.total_minor = OLD.total_minor) '
      "BEGIN SELECT RAISE(ABORT, 'posted purchase invoices are immutable'); "
      'END',
  'CREATE TRIGGER IF NOT EXISTS trg_purchase_invoices_no_delete '
      'BEFORE DELETE ON purchase_invoices '
      "BEGIN SELECT RAISE(ABORT, 'purchase invoices cannot be deleted'); END",
  // Lines can only be written while the invoice is a draft.
  'CREATE TRIGGER IF NOT EXISTS trg_purchase_items_insert_draft_only '
      'BEFORE INSERT ON purchase_invoice_items '
      "WHEN (SELECT status FROM purchase_invoices WHERE id = NEW.invoice_id) "
      "<> 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted purchase invoices are immutable'); "
      'END',
  'CREATE TRIGGER IF NOT EXISTS trg_purchase_items_update_draft_only '
      'BEFORE UPDATE ON purchase_invoice_items '
      "WHEN (SELECT status FROM purchase_invoices WHERE id = OLD.invoice_id) "
      "<> 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted purchase invoices are immutable'); "
      'END',
  'CREATE TRIGGER IF NOT EXISTS trg_purchase_items_delete_draft_only '
      'BEFORE DELETE ON purchase_invoice_items '
      "WHEN (SELECT status FROM purchase_invoices WHERE id = OLD.invoice_id) "
      "<> 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted purchase invoices are immutable'); "
      'END',
];

/// Extra SQL introduced by schema version 5 (sales). Runs on fresh
/// installs and as part of the 4 -> 5 upgrade; every statement is
/// idempotent.
const List<String> kSchemaExtraStatementsV5 = [
  // Document numbers are unique once assigned.
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_invoices_number '
      'ON sales_invoices (number) WHERE number IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer_date '
      'ON sales_invoices (customer_id, invoice_date)',
  'CREATE INDEX IF NOT EXISTS idx_sales_invoices_status '
      'ON sales_invoices (status)',
  'CREATE INDEX IF NOT EXISTS idx_sales_items_invoice '
      'ON sales_invoice_items (invoice_id)',
  'CREATE INDEX IF NOT EXISTS idx_sales_items_product '
      'ON sales_invoice_items (product_id)',
  // Posted, voided and cancelled invoices are immutable. The one allowed
  // change is posted -> voided, which must leave every financial and
  // identifying column untouched.
  'CREATE TRIGGER IF NOT EXISTS trg_sales_invoices_protect '
      'BEFORE UPDATE ON sales_invoices '
      "WHEN OLD.status IN ('posted','voided','cancelled') AND NOT ("
      "OLD.status = 'posted' AND NEW.status = 'voided' "
      'AND NEW.number IS OLD.number '
      'AND NEW.customer_id IS OLD.customer_id '
      'AND NEW.customer_name = OLD.customer_name '
      'AND NEW.invoice_date = OLD.invoice_date '
      'AND NEW.currency_code = OLD.currency_code '
      'AND NEW.decimal_places = OLD.decimal_places '
      'AND NEW.subtotal_minor = OLD.subtotal_minor '
      'AND NEW.discount_total_minor = OLD.discount_total_minor '
      'AND NEW.net_total_minor = OLD.net_total_minor '
      'AND NEW.tax_total_minor = OLD.tax_total_minor '
      'AND NEW.total_minor = OLD.total_minor) '
      "BEGIN SELECT RAISE(ABORT, 'posted sales invoices are immutable'); "
      'END',
  'CREATE TRIGGER IF NOT EXISTS trg_sales_invoices_no_delete '
      'BEFORE DELETE ON sales_invoices '
      "BEGIN SELECT RAISE(ABORT, 'sales invoices cannot be deleted'); END",
  // Lines can only be written while the invoice is a draft.
  'CREATE TRIGGER IF NOT EXISTS trg_sales_items_insert_draft_only '
      'BEFORE INSERT ON sales_invoice_items '
      "WHEN (SELECT status FROM sales_invoices WHERE id = NEW.invoice_id) "
      "<> 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted sales invoices are immutable'); "
      'END',
  'CREATE TRIGGER IF NOT EXISTS trg_sales_items_update_draft_only '
      'BEFORE UPDATE ON sales_invoice_items '
      "WHEN (SELECT status FROM sales_invoices WHERE id = OLD.invoice_id) "
      "<> 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted sales invoices are immutable'); "
      'END',
  'CREATE TRIGGER IF NOT EXISTS trg_sales_items_delete_draft_only '
      'BEFORE DELETE ON sales_invoice_items '
      "WHEN (SELECT status FROM sales_invoices WHERE id = OLD.invoice_id) "
      "<> 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted sales invoices are immutable'); "
      'END',
];

/// Extra SQL introduced by schema version 6 (payments). Runs on fresh
/// installs and as part of the 5 -> 6 upgrade; every statement is
/// idempotent.
const List<String> kSchemaExtraStatementsV6 = [
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_methods_name_active '
      'ON payment_methods (lower(name)) WHERE archived_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_number ON payments (number)',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_idempotency '
      'ON payments (idempotency_key)',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_reversals_payment '
      'ON payment_reversals (payment_id)',
  'CREATE INDEX IF NOT EXISTS idx_payments_customer '
      'ON payments (customer_id, payment_date)',
  'CREATE INDEX IF NOT EXISTS idx_payments_supplier '
      'ON payments (supplier_id, payment_date)',
  'CREATE INDEX IF NOT EXISTS idx_payments_refund_of '
      'ON payments (refund_of_payment_id)',
  'CREATE INDEX IF NOT EXISTS idx_payment_allocations_payment '
      'ON payment_allocations (payment_id)',
  'CREATE INDEX IF NOT EXISTS idx_payment_allocations_sales '
      'ON payment_allocations (sales_invoice_id)',
  'CREATE INDEX IF NOT EXISTS idx_payment_allocations_purchase '
      'ON payment_allocations (purchase_invoice_id)',
  // Payments, allocations and reversals are append-only: money records are
  // cancelled by reversal, never changed or removed.
  'CREATE TRIGGER IF NOT EXISTS trg_payments_no_update '
      'BEFORE UPDATE ON payments '
      "BEGIN SELECT RAISE(ABORT, 'payments are append-only'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_payments_no_delete '
      'BEFORE DELETE ON payments '
      "BEGIN SELECT RAISE(ABORT, 'payments are append-only'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_payment_allocations_no_update '
      'BEFORE UPDATE ON payment_allocations '
      "BEGIN SELECT RAISE(ABORT, 'payment allocations are append-only'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_payment_allocations_no_delete '
      'BEFORE DELETE ON payment_allocations '
      "BEGIN SELECT RAISE(ABORT, 'payment allocations are append-only'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_payment_reversals_no_update '
      'BEFORE UPDATE ON payment_reversals '
      "BEGIN SELECT RAISE(ABORT, 'payment reversals are append-only'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_payment_reversals_no_delete '
      'BEFORE DELETE ON payment_reversals '
      "BEGIN SELECT RAISE(ABORT, 'payment reversals are append-only'); END",
  // Payments take positive allocations, refunds negative ones.
  'CREATE TRIGGER IF NOT EXISTS trg_payment_allocations_sign '
      'BEFORE INSERT ON payment_allocations '
      "WHEN ((SELECT kind FROM payments WHERE id = NEW.payment_id) = 'payment' "
      'AND NEW.amount_minor < 0) '
      "OR ((SELECT kind FROM payments WHERE id = NEW.payment_id) = 'refund' "
      'AND NEW.amount_minor > 0) '
      "BEGIN SELECT RAISE(ABORT, 'allocation sign does not match payment kind'); "
      'END',
  // Defence in depth against over-allocation: what active payments have
  // settled on an invoice always stays between 0 and the invoice total.
  'CREATE TRIGGER IF NOT EXISTS trg_payment_allocations_limit_sales '
      'BEFORE INSERT ON payment_allocations '
      'WHEN NEW.sales_invoice_id IS NOT NULL AND ('
      'COALESCE((SELECT SUM(a.amount_minor) FROM payment_allocations a '
      'WHERE a.sales_invoice_id = NEW.sales_invoice_id '
      'AND a.payment_id NOT IN (SELECT payment_id FROM payment_reversals)), 0) '
      '+ NEW.amount_minor) NOT BETWEEN 0 AND '
      '(SELECT total_minor FROM sales_invoices WHERE id = NEW.sales_invoice_id) '
      "BEGIN SELECT RAISE(ABORT, 'allocation exceeds the invoice total'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_payment_allocations_limit_purchase '
      'BEFORE INSERT ON payment_allocations '
      'WHEN NEW.purchase_invoice_id IS NOT NULL AND ('
      'COALESCE((SELECT SUM(a.amount_minor) FROM payment_allocations a '
      'WHERE a.purchase_invoice_id = NEW.purchase_invoice_id '
      'AND a.payment_id NOT IN (SELECT payment_id FROM payment_reversals)), 0) '
      '+ NEW.amount_minor) NOT BETWEEN 0 AND '
      '(SELECT total_minor FROM purchase_invoices '
      'WHERE id = NEW.purchase_invoice_id) '
      "BEGIN SELECT RAISE(ABORT, 'allocation exceeds the invoice total'); END",
];

/// Extra SQL introduced by schema version 7 (returns). Runs on fresh
/// installs and as part of the 6 -> 7 upgrade; every statement is
/// idempotent.
///
/// Returns are append-only. Defence in depth, in addition to the checks of
/// the use case: a return needs a posted invoice, its lines must belong to
/// that invoice, the returned quantity, net and tax of an invoice line can
/// never add up to more than the line, and an invoice that has returns can
/// no longer be voided.
final List<String> kSchemaExtraStatementsV7 = [
  ..._returnStatements(
    table: 'sales_returns',
    items: 'sales_return_items',
    invoices: 'sales_invoices',
    invoiceItems: 'sales_invoice_items',
    partyColumn: 'customer_id',
    label: 'sales',
  ),
  ..._returnStatements(
    table: 'purchase_returns',
    items: 'purchase_return_items',
    invoices: 'purchase_invoices',
    invoiceItems: 'purchase_invoice_items',
    partyColumn: 'supplier_id',
    label: 'purchase',
  ),
];

List<String> _returnStatements({
  required String table,
  required String items,
  required String invoices,
  required String invoiceItems,
  required String partyColumn,
  required String label,
}) {
  String appendOnly(String name, String on, String verb) =>
      'CREATE TRIGGER IF NOT EXISTS trg_${name}_no_$verb '
      'BEFORE ${verb.toUpperCase()} ON $on '
      "BEGIN SELECT RAISE(ABORT, '$on is append-only'); END";
  String taken(String column) =>
      'COALESCE((SELECT SUM(x.$column) FROM $items x '
      'WHERE x.invoice_item_id = NEW.invoice_item_id), 0)';
  return [
    'CREATE UNIQUE INDEX IF NOT EXISTS uq_${table}_number '
        'ON $table (number)',
    'CREATE UNIQUE INDEX IF NOT EXISTS uq_${table}_idempotency '
        'ON $table (idempotency_key)',
    'CREATE INDEX IF NOT EXISTS idx_${table}_invoice '
        'ON $table (invoice_id)',
    'CREATE INDEX IF NOT EXISTS idx_${table}_party '
        'ON $table ($partyColumn, return_date)',
    'CREATE INDEX IF NOT EXISTS idx_${items}_return ON $items (return_id)',
    'CREATE INDEX IF NOT EXISTS idx_${items}_invoice_item '
        'ON $items (invoice_item_id)',
    appendOnly(table, table, 'update'),
    appendOnly(table, table, 'delete'),
    appendOnly(items, items, 'update'),
    appendOnly(items, items, 'delete'),
    // A return needs a posted invoice.
    'CREATE TRIGGER IF NOT EXISTS trg_${table}_posted_invoice '
        'BEFORE INSERT ON $table '
        "WHEN (SELECT status FROM $invoices WHERE id = NEW.invoice_id) "
        "<> 'posted' "
        "BEGIN SELECT RAISE(ABORT, 'only posted invoices can be returned'); "
        'END',
    // A returned line must belong to the return's invoice.
    'CREATE TRIGGER IF NOT EXISTS trg_${items}_same_invoice '
        'BEFORE INSERT ON $items '
        'WHEN (SELECT invoice_id FROM $invoiceItems '
        'WHERE id = NEW.invoice_item_id) IS NOT '
        '(SELECT invoice_id FROM $table WHERE id = NEW.return_id) '
        "BEGIN SELECT RAISE(ABORT, 'line is not on the returned invoice'); "
        'END',
    // Returns of a line never add up to more than the line.
    'CREATE TRIGGER IF NOT EXISTS trg_${items}_not_more_than_sold '
        'BEFORE INSERT ON $items '
        'WHEN ${taken('quantity_milli')} + NEW.quantity_milli > '
        '(SELECT quantity_milli FROM $invoiceItems '
        'WHERE id = NEW.invoice_item_id) '
        'OR ${taken('net_minor')} + NEW.net_minor > '
        '(SELECT net_minor FROM $invoiceItems '
        'WHERE id = NEW.invoice_item_id) '
        'OR ${taken('tax_minor')} + NEW.tax_minor > '
        '(SELECT tax_minor FROM $invoiceItems '
        'WHERE id = NEW.invoice_item_id) '
        "BEGIN SELECT RAISE(ABORT, 'return exceeds the invoiced line'); END",
    // An invoice with returns cannot be voided.
    'CREATE TRIGGER IF NOT EXISTS trg_${invoices}_void_after_returns '
        'BEFORE UPDATE ON $invoices '
        "WHEN NEW.status = 'voided' AND OLD.status <> 'voided' "
        'AND EXISTS (SELECT 1 FROM $table r WHERE r.invoice_id = OLD.id) '
        "BEGIN SELECT RAISE(ABORT, '$label invoices with returns cannot be "
        "voided'); END",
  ];
}

/// Extra SQL introduced by schema version 8 (expenses). Runs on fresh
/// installs and as part of the 7 -> 8 upgrade; every statement is
/// idempotent.
///
/// Posted, voided and cancelled expenses are immutable; the one allowed
/// change is posted -> voided, which must leave every identifying and
/// financial column untouched. Attachments are evidence: they can be added
/// to draft or posted expenses and removed only from drafts.
const List<String> kSchemaExtraStatementsV8 = [
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_expense_categories_name_active '
      'ON expense_categories (lower(name)) WHERE archived_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_expenses_number '
      'ON expenses (number) WHERE number IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses (expense_date)',
  'CREATE INDEX IF NOT EXISTS idx_expenses_category_date '
      'ON expenses (category_id, expense_date)',
  'CREATE INDEX IF NOT EXISTS idx_expenses_status ON expenses (status)',
  'CREATE INDEX IF NOT EXISTS idx_attachments_owner '
      'ON attachments (owner_type, owner_id)',
  'CREATE TRIGGER IF NOT EXISTS trg_expenses_protect '
      'BEFORE UPDATE ON expenses '
      "WHEN OLD.status IN ('posted','voided','cancelled') AND NOT ("
      "OLD.status = 'posted' AND NEW.status = 'voided' "
      'AND NEW.number IS OLD.number '
      'AND NEW.expense_date = OLD.expense_date '
      'AND NEW.category_id = OLD.category_id '
      'AND NEW.category_name = OLD.category_name '
      'AND NEW.description = OLD.description '
      'AND NEW.payee IS OLD.payee '
      'AND NEW.method_id = OLD.method_id '
      'AND NEW.method_name = OLD.method_name '
      'AND NEW.reference IS OLD.reference '
      'AND NEW.notes IS OLD.notes '
      'AND NEW.currency_code = OLD.currency_code '
      'AND NEW.decimal_places = OLD.decimal_places '
      'AND NEW.amount_includes_tax = OLD.amount_includes_tax '
      'AND NEW.tax_rate_id IS OLD.tax_rate_id '
      'AND NEW.tax_name IS OLD.tax_name '
      'AND NEW.tax_rate_bp = OLD.tax_rate_bp '
      'AND NEW.net_minor = OLD.net_minor '
      'AND NEW.tax_minor = OLD.tax_minor '
      'AND NEW.total_minor = OLD.total_minor) '
      "BEGIN SELECT RAISE(ABORT, 'posted expenses are immutable'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_expenses_no_delete '
      'BEFORE DELETE ON expenses '
      "BEGIN SELECT RAISE(ABORT, 'expenses cannot be deleted'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_attachments_no_update '
      'BEFORE UPDATE ON attachments '
      "BEGIN SELECT RAISE(ABORT, 'attachments cannot be changed'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_attachments_insert_open '
      'BEFORE INSERT ON attachments '
      "WHEN NEW.owner_type = 'expense' AND COALESCE("
      '(SELECT status FROM expenses WHERE id = NEW.owner_id), \'\') '
      "NOT IN ('draft','posted') "
      "BEGIN SELECT RAISE(ABORT, 'expense is not open for attachments'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_attachments_delete_draft_only '
      'BEFORE DELETE ON attachments '
      "WHEN OLD.owner_type = 'expense' AND COALESCE("
      '(SELECT status FROM expenses WHERE id = OLD.owner_id), \'\') '
      "<> 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'attachments of posted expenses are kept'); "
      'END',
];

/// Extra SQL introduced by schema version 9 (backup history). Runs on fresh
/// installs and as part of the 8 -> 9 upgrade.
const List<String> kSchemaExtraStatementsV9 = [
  'CREATE INDEX IF NOT EXISTS idx_backup_history_created '
      'ON backup_history (created_at)',
];

/// Extra SQL introduced by schema version 10 (configurable tax model). Runs
/// on fresh installs and as part of the 9 -> 10 upgrade; idempotent.
const List<String> kSchemaExtraStatementsV10 = [
  'CREATE INDEX IF NOT EXISTS idx_products_tax_category '
      'ON products (tax_category_id)',
  // At most one default profile.
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_tax_profiles_default '
      'ON tax_profiles (is_default) WHERE is_default = 1',
  // A rule never changes owner once created: moving it would silently
  // re-tax other documents.
  'CREATE TRIGGER IF NOT EXISTS trg_tax_rules_keep_owner '
      'BEFORE UPDATE OF tax_profile_id, tax_category_id ON tax_rules '
      'WHEN OLD.tax_profile_id <> NEW.tax_profile_id '
      'OR OLD.tax_category_id <> NEW.tax_category_id '
      "BEGIN SELECT RAISE(ABORT, 'a tax rule cannot move to another "
      "profile or category'); END",
];

/// Extra SQL introduced by schema version 11 (product classification and
/// invoice tax snapshots). Runs on fresh installs and as part of the
/// 10 -> 11 upgrade; idempotent.
const List<String> kSchemaExtraStatementsV11 = [
  // At most one primary classification per product.
  'CREATE UNIQUE INDEX IF NOT EXISTS uq_product_classifications_primary '
      'ON product_classifications (product_id) WHERE is_primary = 1',
  // Snapshot rows follow the same draft-only rule as the invoice lines.
  "CREATE TRIGGER IF NOT EXISTS trg_item_tax_components_insert_draft_only "
      "BEFORE INSERT ON invoice_item_tax_components "
      "WHEN (CASE NEW.document_type WHEN 'sales' THEN (SELECT i.status FROM sales_invoice_items li JOIN sales_invoices i ON i.id = li.invoice_id WHERE li.id = NEW.item_id) ELSE (SELECT i.status FROM purchase_invoice_items li JOIN purchase_invoices i ON i.id = li.invoice_id WHERE li.id = NEW.item_id) END) IS NOT 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted invoices are immutable'); END",
  "CREATE TRIGGER IF NOT EXISTS trg_item_tax_components_update_draft_only "
      "BEFORE UPDATE ON invoice_item_tax_components "
      "WHEN (CASE OLD.document_type WHEN 'sales' THEN (SELECT i.status FROM sales_invoice_items li JOIN sales_invoices i ON i.id = li.invoice_id WHERE li.id = OLD.item_id) ELSE (SELECT i.status FROM purchase_invoice_items li JOIN purchase_invoices i ON i.id = li.invoice_id WHERE li.id = OLD.item_id) END) IS NOT 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted invoices are immutable'); END",
  "CREATE TRIGGER IF NOT EXISTS trg_item_tax_components_delete_draft_only "
      "BEFORE DELETE ON invoice_item_tax_components "
      "WHEN (CASE OLD.document_type WHEN 'sales' THEN (SELECT i.status FROM sales_invoice_items li JOIN sales_invoices i ON i.id = li.invoice_id WHERE li.id = OLD.item_id) ELSE (SELECT i.status FROM purchase_invoice_items li JOIN purchase_invoices i ON i.id = li.invoice_id WHERE li.id = OLD.item_id) END) IS NOT 'draft' "
      "BEGIN SELECT RAISE(ABORT, 'posted invoices are immutable'); END",
];

/// Extra SQL introduced by schema version 12 (hash-chained audit events).
/// Runs on fresh installs and as part of the 11 -> 12 upgrade; idempotent.
const List<String> kSchemaExtraStatementsV12 = [
  // Append-only: no edit and no delete, whatever the caller.
  'CREATE TRIGGER IF NOT EXISTS trg_audit_events_no_update '
      'BEFORE UPDATE ON audit_events '
      "BEGIN SELECT RAISE(ABORT, 'audit events cannot be changed'); END",
  'CREATE TRIGGER IF NOT EXISTS trg_audit_events_no_delete '
      'BEFORE DELETE ON audit_events '
      "BEGIN SELECT RAISE(ABORT, 'audit events cannot be deleted'); END",
];
