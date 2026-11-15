# Database Schema — `inventory_management.sqlite`

## Conventions
- PK: `id TEXT` (UUID v4). FKs enforced (`PRAGMA foreign_keys = ON` in Drift `beforeOpen`; verified by a test).
- Timestamps: UTC, stored as integer epoch milliseconds (`created_at`, `updated_at`).
- Money: `INTEGER` minor units, column suffix `_minor`. Tax rates: `INTEGER` basis points, suffix `_bp`. Quantities: `INTEGER` milli-units, suffix `_milli`.
- Master data: soft delete via `archived_at` (nullable). Posted documents are never deleted.
- Every document line snapshots product name, SKU, unit, price, discount, tax, totals.
- Every document header snapshots currency code + decimal places.
- CHECK constraints: non-negative amounts/quantities, valid enums, exactly-one-invoice-type on allocations.

## Phase 1 tables (initial migration, schemaVersion 1)

### business_profiles
`id`, `name` NOT NULL, `address`, `phone`, `email`, `tax_id`, `logo_path`, `created_at`, `updated_at`. Single active row.

### app_settings
`key` PK, `value` NOT NULL, `updated_at`. Holds currency code, currency decimals, locale, date format, theme mode, approval flags, backup reminder prefs.

### categories
`id`, `name` NOT NULL, `description`, `parent_id` → categories (nullable, reserved), `archived_at`, `created_at`, `updated_at`. UNIQUE(`name`) among non-archived (partial unique index).

### units
`id`, `name` NOT NULL, `symbol` NOT NULL, `decimal_places` INT CHECK 0–3, `archived_at`, timestamps. UNIQUE(`symbol`).

### tax_rates
`id`, `name`, `rate_bp` INT CHECK 0–100000, `is_exempt` BOOL, `archived_at`, timestamps.

### products
`id`, `sku` NOT NULL, `barcode`, `name` NOT NULL, `description`, `category_id` → categories, `unit_id` → units NOT NULL, `purchase_price_minor`, `selling_price_minor` (CHECK ≥0), `price_includes_tax` BOOL, `tax_rate_id` → tax_rates (nullable = exempt/none), `reorder_level_milli` (CHECK ≥0), `image_path`, `archived_at`, timestamps.
Indexes: UNIQUE(`sku`), UNIQUE(`barcode`) WHERE barcode IS NOT NULL, (`category_id`), (`name`).

### inventory_balances
`product_id` PK → products, `quantity_on_hand_milli` CHECK ≥ 0, `inventory_value_minor` CHECK ≥ 0, `updated_at`. Projection of the ledger.

### stock_movements (append-only)
`id`, `product_id` → products, `movement_type` (openingStock, purchase, sale, salesReturn, purchaseReturn, adjustmentIn, adjustmentOut, reversal), `quantity_delta_milli` (signed, non-zero), `total_cost_minor` (signed), `unit_cost_minor_snapshot`, `source_type`, `source_id`, `source_line_id`, `reason`, `occurred_at`, `created_at`.
Indexes: (`product_id`, `occurred_at`), UNIQUE(`source_type`,`source_id`,`source_line_id`,`movement_type`) WHERE source_id IS NOT NULL.
Triggers/guards: no UPDATE/DELETE on this table (enforced by `BEFORE UPDATE/DELETE ... RAISE(ABORT)` triggers added in the Phase 1 migration).

## Later tables (added by migration in the phase shown)

| Phase | Tables | Key columns / rules |
|---|---|---|
| 2 | customers, suppliers | `name`, `phone`, `email`, address fields, `tax_id`, `opening_balance_minor` (signed: + they owe us / we owe them), `archived_at` |
| 3 | (none new; stock_movements/balances in use) | reconciliation query compares SUM(ledger) vs balances |
| 4 | purchase_invoices, purchase_invoice_items | header: `document_number` (nullable until posted), `supplier_id`, `status`, `invoice_date`, `due_date`, `currency_code`, `currency_decimals`, `subtotal_minor`, `discount_minor`, `tax_minor`, `total_minor`, `posted_at`, `voided_at`, `reverses_id`. Line: snapshots (`product_name`, `sku`, `unit_symbol`, `unit_decimals`), `quantity_milli`, `unit_price_minor`, `discount_*`, `tax_rate_bp`, `tax_minor`, `line_total_minor`, `price_includes_tax` |
| 4–5 | document_sequences, tax_groups, tax_group_components, payment_methods | sequence: (`document_type`, `prefix`) PK, `next_number`, `padding` |
| 5 | sales_invoices, sales_invoice_items | same shape as purchases + `customer_id` (nullable for walk-in), `cogs_minor` per line stored at posting |
| 6 | payments, payment_allocations, payment_reversals | payment: `direction` (received/paid), `party_type`, `party_id`, `amount_minor`, `method_id`, `idempotency_key` UNIQUE, `paid_at`. Allocation: `payment_id`, `sales_invoice_id` XOR `purchase_invoice_id` (CHECK exactly one), `amount_minor` > 0. Reversal: `payment_id`, `reason`, `reversed_at` (payment row never deleted) |
| 7 | sales_returns(+items), purchase_returns(+items) | `original_invoice_id`, `original_item_id`, `quantity_milli`, `reason`, `settlement` (refund/credit), restock flag |
| 8 | expense_categories | `name` (unique among active, case-insensitive), `description`, `archived_at`; 8 defaults seeded (`ec-*` ids) |
| 8 | expenses | `number` (set when posted, unique), `status` (draft/posted/cancelled/voided), `expense_date` (UTC midnight), `category_id` + `category_name`, `description`, `payee`, `method_id` + `method_name`, `reference`, `notes`, `currency_code`, `decimal_places`, `amount_includes_tax`, `tax_rate_id`/`tax_name`/`tax_rate_bp`, `net_minor`, `tax_minor`, `total_minor` (CHECK total = net + tax, total > 0), `posted_at`/`cancelled_at`/`voided_at`/`void_reason`. Posted rows immutable (trigger); never deleted |
| 8 | attachments | `owner_type` (`expense` for now), `owner_id`, `file_name`, `stored_path` (relative), `mime_type`, `size_bytes`; insert only for draft/posted expenses, delete only for drafts, never updated (triggers). SHA-256 per file is added with backup in Phase 10 |
| 3+ | audit_logs | `entity_type`, `entity_id`, `action`, `summary`, `occurred_at` (no sensitive payloads) |
| 10 | backup_history | `file_name`, `created_at`, `size_bytes`, `sha256`, `location`, `status` |

## Derived calculations (queries, not stored)
- **Payment status:** `unpaid` (allocated = 0), `partiallyPaid`, `paid` (allocated ≥ total), `overdue` (unpaid/partial and due_date < today), `partiallyRefunded`/`refunded` (refund allocations), `writtenOff` (explicit write-off record).
- **Customer outstanding** = opening balance + Σ posted sales totals − Σ non-reversed allocations − Σ credit-settled sales returns (+ refunds paid out).
- **Supplier outstanding** mirrors this with purchases.
- **Inventory value** = Σ `inventory_value_minor`.


## Phase 1 implementation notes
- Timestamps are plain `INTEGER` epoch milliseconds (UTC), not Drift `DateTime` columns (which default to seconds).
- Extra CHECKs implemented on `stock_movements`: movement type whitelist; quantity sign must match movement type; cost sign must match quantity sign; adjustments require a non-blank reason; `source_type`/`source_id` both set or both null; a source id requires a source line id.
- `inventory_balances`: quantity >= 0, value >= 0, and zero quantity implies zero value.
- `tax_rates`: an exempt rate must have `rate_bp = 0`.
- Partial/expression indexes and the append-only triggers are created by `lib/core/database/schema_extras.dart`.
- Default `app_settings` rows seeded on create: `currency_code`, `currency_decimal_places`, `locale`, `theme_mode`.


## Schema version 2 (Phase 2)
Adds `customers` and `suppliers`, identical in shape: `id`, `name`, `phone`, `email`, `address`, `city`, `state`, `postal_code`, `tax_id`, `notes`, `opening_balance_minor` (signed; positive = amount owed to the business for customers / owed by the business for suppliers; negative = credit), `archived_at`, `created_at`, `updated_at`. Index on `name`. Not unique by design (people share names).

Behaviour notes:
- Creating a product also inserts its zero `inventory_balances` row in the same transaction.
- `products.image_path` stores a **relative** path (`product_images/...`) resolved against the app documents directory at display time.
- `sku` is stored upper-case; uniqueness is enforced by the unique key (and checked first for friendly errors).
- Money columns carry no currency; products/parties are read using the active currency from `app_settings`. Historical documents (Phase 4+) snapshot their own currency.


## Schema version 3 (Phase 3)
Adds `audit_logs`: `id`, `entity_type`, `entity_id`, `action`, `summary`, `occurred_at`; index on `(entity_type, entity_id, occurred_at)`; `BEFORE UPDATE/DELETE` triggers make it append-only (see `kSchemaExtraStatementsV3`). Written in the same transaction as the change it describes.

`stock_movements` rows written in Phase 3 use types `openingStock`, `adjustmentIn`, `adjustmentOut`; the document-sourced columns (`source_*`) stay empty until Phases 4-7. For manual operations the movement row is its own record.

## Schema version 4 (Phase 4)
Adds `document_sequences`, `purchase_invoices`, `purchase_invoice_items`.

**document_sequences**: `key` (PK), `last_value` (>= 0). Incremented inside the transaction that uses the number (upsert, then read), so a rollback does not consume a number.

**purchase_invoices**: `id`, `number` (NULL until posted; unique via partial index `uq_purchase_invoices_number`), `supplier_id` (FK RESTRICT), `supplier_name` (snapshot), `status` (CHECK in the eight `DocumentStatus` names), `invoice_date`, `due_date`, `supplier_reference`, `notes`, `currency_code` + `decimal_places` (snapshot), `subtotal_minor` (gross), `discount_total_minor`, `net_total_minor`, `tax_total_minor`, `total_minor` (all >= 0), `posted_at`, `cancelled_at`, `voided_at`, `void_reason`, `created_at`, `updated_at`.
Table CHECKs: a number exists exactly for `posted`/`voided`; posted/voided need `posted_at`; voided needs `voided_at` and `void_reason`; `total = net + tax`.

**purchase_invoice_items**: `id`, `invoice_id` (FK RESTRICT), `line_no` (unique per invoice), `product_id` (FK RESTRICT), snapshots `product_name`, `sku`, `unit_symbol`, `unit_decimal_places`, `quantity_milli` (> 0), `unit_price_minor`, `price_includes_tax`, `discount_type` (`none|percent|amount`), `discount_value` (basis points or minor units), `tax_rate_bp`, `tax_name`, amounts `gross_minor`, `discount_minor`, `net_minor`, `tax_minor`, `total_minor`. CHECKs: `total = net + tax`, `discount <= gross`.

**Immutability triggers** (`kSchemaExtraStatementsV4`): posted/voided/cancelled invoices cannot be updated, except `posted → voided` with every identifying and financial column unchanged; invoices cannot be deleted; lines can only be inserted, updated or deleted while the invoice is a `draft`.

**Indexes**: `(supplier_id, invoice_date)`, `(status)`, lines by `invoice_id` and `product_id`. V4 also (re)creates `idx_audit_logs_entity`, which upgraded v2/v3 databases never received because `Migrator.createTable` does not create `@TableIndex` indexes.

Stock movements written by purchases: type `purchase` (posting) and `reversal` (void), with `source_type = purchase_invoice`, `source_id` = invoice id, `source_line_id` = line id.

## Schema version 5 (Phase 5)
Adds `sales_invoices` and `sales_invoice_items`, the same shape as the purchase tables with two differences: `customer_id` is **nullable** (walk-in sale; still an FK RESTRICT when set) and the party snapshot is `customer_name`/`customer_reference`. Same CHECKs (number exists exactly for posted/voided, `total = net + tax`, `discount <= gross`), same partial unique index `uq_sales_invoices_number`, same immutability triggers (`kSchemaExtraStatementsV5`; the `posted -> voided` exception compares `customer_id` with `IS` so NULL walk-in sales work), and indexes on `(customer_id, invoice_date)`, `status`, and the line foreign keys. Cost of goods sold is not stored on the invoice; it lives in the stock ledger (`sale` movements).

## Schema version 7 (Phase 7)
Adds `sales_returns`, `sales_return_items`, `purchase_returns`, `purchase_return_items`.

**sales_returns / purchase_returns**: `id`, `number` (unique; `SRN-`/`PRN-`), `invoice_id` (FK RESTRICT), `invoice_number`, party id (`customer_id` nullable for walk-in sales / `supplier_id` not null; FK RESTRICT) and name snapshot, `return_date`, `reason`, `notes`, `currency_code`, `decimal_places`, `net_total_minor`, `tax_total_minor`, `total_minor`, `refund_amount_minor`, `refund_method_id` (FK RESTRICT) + `refund_method_name`, `refund_reference`, `idempotency_key` (unique), `created_at`. CHECKs: `total = net + tax`; `refund <= total`; `(refund > 0) = (refund_method_id IS NOT NULL)`.

**sales_return_items / purchase_return_items**: `id`, `return_id` (FK), `line_no`, `invoice_item_id` (FK to the original line), `product_id` (FK) with snapshots `product_name`, `sku`, `unit_symbol`, `unit_decimal_places`, `quantity_milli` (> 0), `net_minor`, `tax_minor`, `total_minor`, `stock_cost_minor` (value that entered/left stock), `note`; sales items also `restocked`. Unique `(return_id, line_no)` and `(return_id, invoice_item_id)`. CHECKs: `total = net + tax`; sales: `restocked = 1 OR stock_cost_minor = 0`.

**Triggers / indexes** (`kSchemaExtraStatementsV7`, generated per kind): all four tables are append-only; a return needs a `posted` invoice; a returned line must belong to the return's invoice; Σ returned quantity, net and tax of an invoice line can never exceed the line; an invoice with returns cannot move to `voided`. Indexes on number, idempotency key, invoice, `(party, return_date)` and the item foreign keys.

Stock movements written by returns: `salesReturn` (restock) and `purchaseReturn`, with `source_type = sales_return | purchase_return`, `source_id` = return id, `source_line_id` = return line id.
