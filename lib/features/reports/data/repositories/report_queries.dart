// GENERATED from tool-free templates; edit with care. Plain SQL strings only.
//
// Parameter order of every query is documented above it. Dates are UTC
// midnight epoch milliseconds (the storage format of document dates).
// Optional filters use `(? IS NULL OR col = ?)` so the parameter list has a
// fixed shape.

/// Posted sales documents. Params: from, to, currency, decimals, party, party.
const String salesFiguresSql = r'''
SELECT COUNT(*) AS cnt,
       COALESCE(SUM(net_total_minor), 0) AS net,
       COALESCE(SUM(tax_total_minor), 0) AS tax,
       COALESCE(SUM(total_minor), 0) AS total
FROM sales_invoices
WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR customer_id = ?)
''';

/// Returns. Params: from, to, currency, decimals, party, party.
const String salesReturnFiguresSql = r'''
SELECT COUNT(*) AS cnt,
       COALESCE(SUM(net_total_minor), 0) AS net,
       COALESCE(SUM(tax_total_minor), 0) AS tax,
       COALESCE(SUM(total_minor), 0) AS total
FROM sales_returns
WHERE return_date >= ? AND return_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR customer_id = ?)
''';

/// Documents and returns in another currency. Params: from, to, currency,
/// decimals, party, party (documents), then the same six for returns.
const String salesOtherCurrencySql = r'''
SELECT (SELECT COUNT(*) FROM sales_invoices
        WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
          AND NOT (currency_code = ? AND decimal_places = ?)
          AND (? IS NULL OR customer_id = ?))
     + (SELECT COUNT(*) FROM sales_returns
        WHERE return_date >= ? AND return_date <= ?
          AND NOT (currency_code = ? AND decimal_places = ?)
          AND (? IS NULL OR customer_id = ?)) AS cnt
''';

/// Newest invoices. Params: from, to, currency, decimals, party, party, limit.
const String salesRowsSql = r'''
SELECT id, number, invoice_date, customer_name AS party_name,
       net_total_minor, tax_total_minor, total_minor
FROM sales_invoices
WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR customer_id = ?)
ORDER BY invoice_date DESC, number DESC
LIMIT ?
''';

/// Newest invoices of any date. Params: currency, decimals, limit.
const String recentSalesSql = r'''
SELECT id, number, invoice_date, customer_name AS party_name,
       net_total_minor, tax_total_minor, total_minor
FROM sales_invoices
WHERE status = 'posted' AND currency_code = ? AND decimal_places = ?
ORDER BY invoice_date DESC, posted_at DESC, number DESC
LIMIT ?
''';

/// Net amount per day. Params: from, to, currency, decimals, party, party.
const String salesDailySql = r'''
SELECT invoice_date AS day, SUM(net_total_minor) AS amount
FROM sales_invoices
WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR customer_id = ?)
GROUP BY invoice_date
ORDER BY invoice_date
''';

/// Returned net amount per day. Params: from, to, currency, decimals,
/// party, party.
const String salesReturnsDailySql = r'''
SELECT return_date AS day, SUM(net_total_minor) AS amount
FROM sales_returns
WHERE return_date >= ? AND return_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR customer_id = ?)
GROUP BY return_date
ORDER BY return_date
''';

/// Posted purchase documents. Params: from, to, currency, decimals, party, party.
const String purchaseFiguresSql = r'''
SELECT COUNT(*) AS cnt,
       COALESCE(SUM(net_total_minor), 0) AS net,
       COALESCE(SUM(tax_total_minor), 0) AS tax,
       COALESCE(SUM(total_minor), 0) AS total
FROM purchase_invoices
WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR supplier_id = ?)
''';

/// Returns. Params: from, to, currency, decimals, party, party.
const String purchaseReturnFiguresSql = r'''
SELECT COUNT(*) AS cnt,
       COALESCE(SUM(net_total_minor), 0) AS net,
       COALESCE(SUM(tax_total_minor), 0) AS tax,
       COALESCE(SUM(total_minor), 0) AS total
FROM purchase_returns
WHERE return_date >= ? AND return_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR supplier_id = ?)
''';

/// Documents and returns in another currency. Params: from, to, currency,
/// decimals, party, party (documents), then the same six for returns.
const String purchaseOtherCurrencySql = r'''
SELECT (SELECT COUNT(*) FROM purchase_invoices
        WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
          AND NOT (currency_code = ? AND decimal_places = ?)
          AND (? IS NULL OR supplier_id = ?))
     + (SELECT COUNT(*) FROM purchase_returns
        WHERE return_date >= ? AND return_date <= ?
          AND NOT (currency_code = ? AND decimal_places = ?)
          AND (? IS NULL OR supplier_id = ?)) AS cnt
''';

/// Newest invoices. Params: from, to, currency, decimals, party, party, limit.
const String purchaseRowsSql = r'''
SELECT id, number, invoice_date, supplier_name AS party_name,
       net_total_minor, tax_total_minor, total_minor
FROM purchase_invoices
WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR supplier_id = ?)
ORDER BY invoice_date DESC, number DESC
LIMIT ?
''';

/// Newest invoices of any date. Params: currency, decimals, limit.
const String recentPurchaseSql = r'''
SELECT id, number, invoice_date, supplier_name AS party_name,
       net_total_minor, tax_total_minor, total_minor
FROM purchase_invoices
WHERE status = 'posted' AND currency_code = ? AND decimal_places = ?
ORDER BY invoice_date DESC, posted_at DESC, number DESC
LIMIT ?
''';

/// Net amount per day. Params: from, to, currency, decimals, party, party.
const String purchaseDailySql = r'''
SELECT invoice_date AS day, SUM(net_total_minor) AS amount
FROM purchase_invoices
WHERE status = 'posted' AND invoice_date >= ? AND invoice_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR supplier_id = ?)
GROUP BY invoice_date
ORDER BY invoice_date
''';

/// Returned net amount per day. Params: from, to, currency, decimals,
/// party, party.
const String purchaseReturnsDailySql = r'''
SELECT return_date AS day, SUM(net_total_minor) AS amount
FROM purchase_returns
WHERE return_date >= ? AND return_date <= ?
  AND currency_code = ? AND decimal_places = ?
  AND (? IS NULL OR supplier_id = ?)
GROUP BY return_date
ORDER BY return_date
''';

/// Cost of goods sold. Params: from, to, currency, decimals (twice: the
/// first four for sold goods, the next four for goods put back in stock).
const String costOfGoodsSoldSql = r'''
SELECT
  (SELECT COALESCE(-SUM(m.total_cost_minor), 0)
     FROM stock_movements m
     JOIN sales_invoices s ON s.id = m.source_id
    WHERE m.source_type = 'sales_invoice' AND m.movement_type = 'sale'
      AND s.status = 'posted'
      AND s.invoice_date >= ? AND s.invoice_date <= ?
      AND s.currency_code = ? AND s.decimal_places = ?) AS sold_cost,
  (SELECT COALESCE(SUM(ri.stock_cost_minor), 0)
     FROM sales_return_items ri
     JOIN sales_returns r ON r.id = ri.return_id
    WHERE r.return_date >= ? AND r.return_date <= ?
      AND r.currency_code = ? AND r.decimal_places = ?) AS returned_cost
''';

/// Sold quantity and revenue per product. Params: from, to, currency,
/// decimals, product, product.
const String productSoldSql = r'''
SELECT i.product_id AS product_id, MIN(i.product_name) AS name,
       MIN(i.sku) AS sku, MIN(i.unit_symbol) AS unit_symbol,
       MIN(i.unit_decimal_places) AS unit_dp,
       SUM(i.quantity_milli) AS qty, SUM(i.net_minor) AS revenue
FROM sales_invoice_items i
JOIN sales_invoices s ON s.id = i.invoice_id
WHERE s.status = 'posted' AND s.invoice_date >= ? AND s.invoice_date <= ?
  AND s.currency_code = ? AND s.decimal_places = ?
  AND (? IS NULL OR i.product_id = ?)
GROUP BY i.product_id
''';

/// Returned quantity, revenue and restocked cost per product. Params: from,
/// to, currency, decimals, product, product.
const String productReturnedSql = r'''
SELECT ri.product_id AS product_id, MIN(ri.product_name) AS name,
       MIN(ri.sku) AS sku, MIN(ri.unit_symbol) AS unit_symbol,
       MIN(ri.unit_decimal_places) AS unit_dp,
       SUM(ri.quantity_milli) AS qty, SUM(ri.net_minor) AS revenue,
       SUM(ri.stock_cost_minor) AS restocked_cost
FROM sales_return_items ri
JOIN sales_returns r ON r.id = ri.return_id
WHERE r.return_date >= ? AND r.return_date <= ?
  AND r.currency_code = ? AND r.decimal_places = ?
  AND (? IS NULL OR ri.product_id = ?)
GROUP BY ri.product_id
''';

/// Cost of the goods sold per product. Params: from, to, currency,
/// decimals, product, product.
const String productCostSql = r'''
SELECT m.product_id AS product_id, COALESCE(-SUM(m.total_cost_minor), 0) AS cost
FROM stock_movements m
JOIN sales_invoices s ON s.id = m.source_id
WHERE m.source_type = 'sales_invoice' AND m.movement_type = 'sale'
  AND s.status = 'posted'
  AND s.invoice_date >= ? AND s.invoice_date <= ?
  AND s.currency_code = ? AND s.decimal_places = ?
  AND (? IS NULL OR m.product_id = ?)
GROUP BY m.product_id
''';

/// Cash entries by method and type. Params (payments): from, to, currency,
/// decimals, includeCustomerSide, customer, customer, includeSupplierSide,
/// supplier, supplier; (sales returns): from, to, currency, decimals,
/// includeCustomerSide, customer, customer; (purchase returns): from, to,
/// currency, decimals, includeSupplierSide, supplier, supplier.
const String cashSql = r'''
SELECT method_id, MIN(method_name) AS method_name, cat,
       SUM(amt) AS amount, COUNT(*) AS cnt
FROM (
  SELECT p.method_id AS method_id, p.method_name AS method_name,
         p.party_type || '/' || p.kind AS cat, p.amount_minor AS amt
  FROM payments p
  LEFT JOIN payment_reversals pr ON pr.payment_id = p.id
  WHERE pr.id IS NULL
      AND p.payment_date >= ? AND p.payment_date <= ?
      AND p.currency_code = ? AND p.decimal_places = ?
      AND ((p.party_type = 'customer' AND ? = 1
            AND (? IS NULL OR p.customer_id = ?))
        OR (p.party_type = 'supplier' AND ? = 1
            AND (? IS NULL OR p.supplier_id = ?)))
  UNION ALL
  SELECT sr.refund_method_id, sr.refund_method_name, 'salesReturnRefund',
         sr.refund_amount_minor
  FROM sales_returns sr
  WHERE sr.refund_amount_minor > 0
    AND sr.return_date >= ? AND sr.return_date <= ?
    AND sr.currency_code = ? AND sr.decimal_places = ?
    AND ? = 1 AND (? IS NULL OR sr.customer_id = ?)
  UNION ALL
  SELECT pu.refund_method_id, pu.refund_method_name, 'purchaseReturnRefund',
         pu.refund_amount_minor
  FROM purchase_returns pu
  WHERE pu.refund_amount_minor > 0
    AND pu.return_date >= ? AND pu.return_date <= ?
    AND pu.currency_code = ? AND pu.decimal_places = ?
    AND ? = 1 AND (? IS NULL OR pu.supplier_id = ?)
)
GROUP BY method_id, cat
''';

/// Cash entries in another currency. Same parameters as [cashSql].
const String cashOtherCurrencySql = r'''
SELECT
  (SELECT COUNT(*)
     FROM payments p
     LEFT JOIN payment_reversals pr ON pr.payment_id = p.id
    WHERE pr.id IS NULL
      AND p.payment_date >= ? AND p.payment_date <= ?
      AND NOT (p.currency_code = ? AND p.decimal_places = ?)
      AND ((p.party_type = 'customer' AND ? = 1
            AND (? IS NULL OR p.customer_id = ?))
        OR (p.party_type = 'supplier' AND ? = 1
            AND (? IS NULL OR p.supplier_id = ?))))
  + (SELECT COUNT(*) FROM sales_returns sr
      WHERE sr.refund_amount_minor > 0
        AND sr.return_date >= ? AND sr.return_date <= ?
        AND NOT (sr.currency_code = ? AND sr.decimal_places = ?)
        AND ? = 1 AND (? IS NULL OR sr.customer_id = ?))
  + (SELECT COUNT(*) FROM purchase_returns pu
      WHERE pu.refund_amount_minor > 0
        AND pu.return_date >= ? AND pu.return_date <= ?
        AND NOT (pu.currency_code = ? AND pu.decimal_places = ?)
        AND ? = 1 AND (? IS NULL OR pu.supplier_id = ?)) AS cnt
''';

/// Stock ledger entries. Params: fromMs (inclusive), toMs (exclusive),
/// product, product, limit.
const String movementRowsSql = r'''
SELECT m.id AS id, m.occurred_at AS occurred_at,
       m.movement_type AS movement_type,
       m.quantity_delta_milli AS qty, m.total_cost_minor AS cost,
       m.reason AS reason, p.name AS product_name, p.sku AS sku,
       u.symbol AS unit_symbol, u.decimal_places AS unit_dp
FROM stock_movements m
JOIN products p ON p.id = m.product_id
JOIN units u ON u.id = p.unit_id
WHERE m.occurred_at >= ? AND m.occurred_at < ?
  AND (? IS NULL OR m.product_id = ?)
ORDER BY m.occurred_at DESC, m.created_at DESC, m.rowid DESC
LIMIT ?
''';

/// Totals over all entries. Params: fromMs (inclusive), toMs (exclusive),
/// product, product.
const String movementTotalsSql = r'''
SELECT COUNT(*) AS cnt,
       COALESCE(SUM(CASE WHEN m.quantity_delta_milli > 0
                         THEN m.total_cost_minor ELSE 0 END), 0) AS value_in,
       COALESCE(SUM(CASE WHEN m.quantity_delta_milli < 0
                         THEN -m.total_cost_minor ELSE 0 END), 0) AS value_out
FROM stock_movements m
WHERE m.occurred_at >= ? AND m.occurred_at < ?
  AND (? IS NULL OR m.product_id = ?)
''';
