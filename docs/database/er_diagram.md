# ER Diagram

```mermaid
erDiagram
  CATEGORIES ||--o{ PRODUCTS : has
  UNITS ||--o{ PRODUCTS : measures
  TAX_RATES ||--o{ PRODUCTS : taxes
  PRODUCTS ||--|| INVENTORY_BALANCES : projects
  PRODUCTS ||--o{ STOCK_MOVEMENTS : ledger
  CUSTOMERS ||--o{ SALES_INVOICES : buys
  SUPPLIERS ||--o{ PURCHASE_INVOICES : supplies
  SALES_INVOICES ||--|{ SALES_INVOICE_ITEMS : contains
  PURCHASE_INVOICES ||--|{ PURCHASE_INVOICE_ITEMS : contains
  PRODUCTS ||--o{ SALES_INVOICE_ITEMS : snapshotted_in
  PRODUCTS ||--o{ PURCHASE_INVOICE_ITEMS : snapshotted_in
  PAYMENTS ||--o{ PAYMENT_ALLOCATIONS : allocates
  SALES_INVOICES ||--o{ PAYMENT_ALLOCATIONS : settled_by
  PURCHASE_INVOICES ||--o{ PAYMENT_ALLOCATIONS : settled_by
  PAYMENTS ||--o{ PAYMENT_REVERSALS : reversed_by
  PAYMENT_METHODS ||--o{ PAYMENTS : used_in
  SALES_INVOICES ||--o{ SALES_RETURNS : returned_via
  SALES_RETURNS ||--|{ SALES_RETURN_ITEMS : contains
  PURCHASE_INVOICES ||--o{ PURCHASE_RETURNS : returned_via
  PURCHASE_RETURNS ||--|{ PURCHASE_RETURN_ITEMS : contains
  EXPENSE_CATEGORIES ||--o{ EXPENSES : groups
  PAYMENT_METHODS ||--o{ EXPENSES : paid_with
  TAX_RATES ||--o{ EXPENSES : taxed_by
  TAX_GROUPS ||--|{ TAX_GROUP_COMPONENTS : composed_of
  TAX_RATES ||--o{ TAX_GROUP_COMPONENTS : used_in
```

`business_profiles`, `app_settings`, `document_sequences` (purchase numbers use it since v4), `audit_logs`, `attachments` (owner is referenced by `owner_type` + `owner_id`, guarded by triggers; expense receipts for now), `backup_history` are standalone (no FK edges) and omitted for clarity. Sales/purchase items → products is a *snapshot* relationship (FK kept for traceability, values copied).
