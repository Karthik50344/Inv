# Dependency Rules

## Allowed
- Presentation → Domain (use cases, entities)
- Data → Domain (implements contracts)
- Infrastructure → Domain/Data contracts
- Any feature domain → `shared/domain` and pure-Dart `core`
- Feature A domain → Feature B **domain contracts** only, following `feature_dependencies.md`

## Forbidden
1. BLoC/Cubit touching Drift, SQL, or DAOs.
2. Widgets calling repositories.
3. Domain importing `package:flutter`, `drift`, `get_it`, or any plugin.
4. Entities depending on Drift row classes.
5. Business rules in widgets.
6. Circular feature dependencies.
7. One BLoC reading or controlling another BLoC.
8. Data layer of feature A importing data layer of feature B.

## Enforcement
- `very_good_analysis` plus `tool/check_imports.dart` (added in Phase 1) that fails when `lib/**/domain/**` imports flutter/drift/get_it/plugins, or `**/presentation/**` imports `**/data/**`.
- Review checklist item in every phase report.

## Cross-feature coordination
Orchestrating use cases (e.g. `PostSalesInvoice`) live in the feature that owns the document and depend on contracts: `InventoryPostingService`, `DocumentNumberService`, `AuditLogger`, `TransactionRunner`.
