# Relationships

| Parent | Child | Cardinality | On delete |
|---|---|---|---|
| categories | products | 1 : N | RESTRICT (archive instead) |
| units | products | 1 : N | RESTRICT |
| tax_rates | products | 1 : N (optional) | RESTRICT |
| products | inventory_balances | 1 : 1 | RESTRICT |
| products | stock_movements | 1 : N | RESTRICT |
| customers | sales_invoices | 1 : N (optional) | RESTRICT |
| suppliers | purchase_invoices | 1 : N | RESTRICT |
| sales_invoices | sales_invoice_items | 1 : N | RESTRICT (drafts: explicit delete of lines) |
| purchase_invoices | purchase_invoice_items | 1 : N | RESTRICT |
| payments | payment_allocations | 1 : N | RESTRICT |
| sales_invoices / purchase_invoices | payment_allocations | 1 : N (exactly one parent per allocation) | RESTRICT |
| payments | payment_reversals | 1 : N | RESTRICT |
| sales_invoices | sales_returns | 1 : N | RESTRICT |
| sales_returns | sales_return_items | 1 : N | RESTRICT |
| purchase_invoices | purchase_returns | 1 : N | RESTRICT |
| purchase_returns | purchase_return_items | 1 : N | RESTRICT |
| expense_categories | expenses | 1 : N | RESTRICT |
| payment_methods | expenses | 1 : N | RESTRICT |
| tax_rates | expenses | 1 : N (optional) | RESTRICT |
| expenses | attachments | 1 : N | no FK; `owner_type`/`owner_id` + triggers |

Rule: no `ON DELETE CASCADE` on anything financial or ledger-related. Historical line items carry snapshots, so master-data edits never alter history; the FK is for traceability only.

Referential traceability for stock: `stock_movements.(source_type, source_id, source_line_id)` is a polymorphic reference (not an FK) to the originating document line; validated in the use case and covered by reconciliation tests.
