# Folder Structure

Baseline is the structure in the master specification, with project name `inventrix`.

```text
inventrix/
├── android/  ios/            # com.rk.inventrix
├── docs/
├── lib/
│   ├── main.dart
│   ├── app/        (app.dart, bootstrap.dart, router/, theme/, di/)
│   ├── core/       (constants, errors, result, database/{tables,migrations}, extensions,
│   │                formatters, validators, utils, services, widgets)
│   ├── shared/     (domain/{entities,value_objects,enums}, presentation/widgets, utilities)
│   ├── features/   (dashboard, products, categories, inventory, customers, suppliers,
│   │                sales, purchases, payments, returns, expenses, reports, backup, settings)
│   └── l10n/
├── test/           # mirrors lib/
├── integration_test/
├── tool/           # check_imports.dart
└── drift_schemas/  # schema snapshots for migration tests
```

Per-feature: `data/{datasources,models,mappers,repositories}`, `domain/{entities,repositories,usecases,services}`, `presentation/{bloc,pages,widgets}`. Folders are created only when they contain files.

## Placement notes
- Value objects (Money, Quantity, TaxRate, Discount, Percentage, DateRange, InvoiceNumber, ProductSku, StockLevel) → `shared/domain/value_objects`.
- `TransactionRunner`, `Result`, `Failure` → `core` (pure Dart files).
- Drift tables → `core/database/tables`; DAOs in the owning feature's `data/datasources`.
- `DocumentStatus`, `PaymentStatus` → `shared/domain/enums`.
- Stock posting logic (movements + WAC) lives in `inventory/domain/services`, exposed to purchases/sales/returns via an `InventoryPostingService` contract.
