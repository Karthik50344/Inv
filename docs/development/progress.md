# Progress

## Phase 0 — Project Analysis and Architecture
**Status:** documentation drafted; **awaiting your review**. Not marked complete.

- Completed: existing-project inspection (none found), architecture, ADRs/risks, dependency list, folder structure, dependency rules, feature graph, schema/relationships/ER/migrations design, workflows, conventions, testing, release checklist, roadmap.
- Remaining: your approval of the decisions flagged in the Phase 0 report.
- Files created: all files under `docs/` (21).
- Tests created/executed: none (no code yet).
- Commands executed: none (no Flutter/Dart SDK in this environment).
- Known issues: package versions unverified (R1); dependency list differs from spec (R2).
- Next: Phase 1 after approval.


## Phase 1 — Project Foundation
**Status:** code written; **partially verified**. Not marked complete (see below).

### What was verified (in the authoring sandbox)
- `dart format .` over all 59 Dart files: ran, no syntax errors.
- `dart analyze` (strict-casts, strict-raw-types, default lints) over the
  pure-Dart subset (`core/errors`, `core/result`, `core/utils`,
  `core/services`, `core/constants`, `shared/domain`, `tool/`): no issues.
- 46 unit tests for rounding, decimal text, `Result`/`Failure`, `Quantity`
  and `Money` executed against a minimal stand-in for `flutter_test`
  (the real package was unavailable): 46/46 passed.
- `tool/check_imports.dart`: passes on `lib/`, and correctly reports
  violations on a deliberately bad sample.

### Not verified (needs Flutter SDK + pub.dev)
- `flutter pub add` resolution and actual package versions.
- `dart run build_runner build` (Drift code generation); `app_database.g.dart`
  does not exist yet, so everything importing `AppDatabase` is uncompiled.
- `flutter analyze` with `very_good_analysis` over the whole project.
- Database tests, migration tests, DI test, router/theme widget tests, the
  transaction tests (written, never executed).
- App launch on Android/iOS, light/dark rendering, platform ID configuration.

### Files created
`lib/` (47 files), `test/` (11 files incl. 1 helper), `tool/check_imports.dart`,
`analysis_options.yaml`, `setup.sh`, `README.md`.

### Known issues / risks
- Drift APIs (`customConstraint`, `TableIndex`, `references(onDelete:)`,
  `uniqueKeys`, `customConstraints`) are used from memory of Drift 2.x and must
  be confirmed by the first `build_runner` run.
- Partial indexes and triggers live in `schema_extras.dart`, outside Drift's
  generated schema; they are not captured by `drift_dev schema dump`.
- `very_good_analysis` may flag style infos that need a cleanup pass.
- Whether `sqlite3_flutter_libs` is still required alongside `drift_flutter`
  depends on the resolved versions.

### Next
Run `setup.sh`, fix whatever the compiler/analyzer/tests report, then
report results so Phase 1 can be closed. Phase 2 starts after that.


## Phase 2 — Master Data Management
**Status:** code written; **partially verified**. Not marked complete. Phase 1 had not yet been run on a Flutter machine when Phase 2 was started, so Phase 2 inherits that unverified base.

### Scope delivered
Categories, units, products (SKU, barcode, prices, tax config, unit, reorder level, image), customers and suppliers: domain entities and use cases, Drift repositories, BLoCs/Cubits, screens, schema v2 migration, tests. Minimal `settings` feature (currency read, tax-rate create) because products need it; the full settings feature stays in Phase 11.

### Verified in the authoring sandbox (Dart 3.13.7; no Flutter SDK, no pub.dev)
- `dart format` over all 196 Dart files: no syntax errors.
- Strict `dart analyze` (strict-casts, strict-raw-types) over: all domain code, shared kernel, validators, the in-memory fakes and all use-case tests; and separately over all BLoC/Cubit sources and their tests: no issues. (Used stand-ins for `equatable`, `flutter_test`, `bloc`, `flutter_bloc`, `bloc_test`.)
- 110 unit tests (value objects, validators, tax rate, category/unit/product/customer/supplier use cases) executed: 110/110 passed.
- 63 BLoC/Cubit tests executed against a minimal `bloc` stand-in: 63/63 passed. Mutation checks confirmed the harness fails when business rules are broken.
- `tool/check_imports.dart`: dependency rules pass.

### NOT verified (needs Flutter SDK + pub.dev)
- `flutter pub add`, Drift code generation (`app_database.g.dart` still absent), `flutter analyze` with `very_good_analysis`.
- Everything that imports Drift, Flutter widgets, `go_router`, `file_picker`, `path_provider` or `intl`: the 7 Drift repositories + mappers, `FileImageStorage`, `MoneyFormatter`, all pages/dialogs/widgets, the router, DI wiring.
- Tests written but never executed: the database suites (`test/core/database/`, incl. the simulated 1->2 upgrade), repository tests (`test/data/`), image storage, money formatter, DI test, and all widget tests (categories, units, products flow, customers, suppliers, router, theme).
- Real `bloc`/`bloc_test`/`flutter_bloc` behaviour (my stand-in mirrors the semantics used here but is not the package).
- Running the app on Android/iOS.

### Files
`lib/` 155 Dart files and `test/` 40 Dart files in total (Phase 1 + 2). New feature folders: settings, categories, customers, suppliers; products extended. Customers and suppliers were generated from one template so they behave identically.

### Known risks to check on the first real run
- Drift API use (`customConstraints`, `TableIndex`, `selectOnly`, `Expression.lower().equalsExp`, `readNullable`) is from memory of Drift 2.x.
- `DropdownButtonFormField(initialValue: ...)` requires a recent Flutter; use `value:` on older SDKs.
- `FilePicker.platform.pickFiles` API differs between `file_picker` major versions.
- `NumberFormat.format(BigInt)` and the `en_IN` grouping assertions in `money_formatter_test.dart`.
- Widget tests rely on fake repositories (no database), but first-run failures in finders/timings are possible.
- Android/iOS permissions for picking images (file_picker usually needs none for the system picker; confirm on device).

### Acceptance criteria (Phase 2)
- Validation enforced (domain-level): **passed** (executed).
- Historical records not corrupted by master-data changes: **partially** — edits never touch other records (tested); invoice snapshots arrive with Phases 4-5.
- Foreign keys respected, CRUD offline, search/filters against SQLite: **unverified** (tests written).
- Tests pass: **partially** (see above).

### Next
Run `bash setup.sh`, fix what the compiler/tests report, then confirm. Phase 3 (Inventory) starts after that.


## Phase 3 — Inventory Management
**Status:** code written; **partially verified**. Not marked complete. Phases 1 and 2 had still not been run on a Flutter machine when this phase was built, so all three phases share the same unverified base.

### Scope delivered
Current stock list with valuation, opening stock, manual stock in/out with mandatory reasons, movement history (paged), low-stock / out-of-stock indicators and report, weighted average cost, reconciliation and audited repair, append-only audit log (schema v3), `TransactionRunner.runResult`.

### Verified in the authoring sandbox (Dart 3.13.7; no Flutter SDK, no pub.dev)
- `dart format` over all Dart files: no syntax errors. `tool/check_imports.dart`: passes.
- Strict `dart analyze` over all domain code, fakes, use cases, BLoC/Cubit sources and their tests (with stand-in packages): no issues.
- **246 tests executed and passing** (73 new): weighted-average-cost calculator incl. rounding edge cases and a 200-round randomized invariant test; opening/adjustment use cases incl. insufficient stock, validation, archived products and rollback on a failing audit or ledger write (fakes emulate rollback); reconciliation and repair; inventory BLoC/Cubits.
- Mutation checks: allowing negative stock is caught by 4 tests. (Removing the explicit "take the whole value" rule is *not* detectable because it is mathematically implied.)

### NOT verified (needs Flutter SDK + pub.dev)
- Drift code generation and everything importing Drift/Flutter: `DriftInventoryRepository`, `DriftAuditLogRepository`, schema v3 + both migration simulations, the real transaction rollback tests (`test/data/inventory_*`), pages, router and DI wiring, and all widget tests.
- The real `bloc`/`bloc_test` packages (stand-ins used).
- Running the app.

### Known risks for the first real run
- `insertOnConflictUpdate`, `CustomExpression('rowid')` ordering and `selectOnly` aggregates are used from memory of Drift 2.x.
- Widget tests rely on fakes; finder/timing adjustments may be needed.
- The Drift atomicity tests (ledger + balance + audit in one transaction) are the most important ones to see pass.

### Acceptance criteria (Phase 3)
- Stock calculations correct; negative stock impossible through supported operations; WAC edge cases pass: **passed (executed against fakes)**.
- Ledger/balance consistency and reconciliation tests: **passed (executed against fakes)**; against SQLite: **unverified**.
- All database operations transactional: **designed and covered by tests that have not yet been run on SQLite**.

### Next
Run `bash setup.sh` and send me the output. Fixing Phases 1-3 together is the best use of the next step. Phase 4 (Purchases) starts after that.


## Phase 4 — Purchase Management
**Status:** code written; **partially verified**. Not marked complete. Phases 1-3 have not been confirmed on a Flutter machine either, so the shared base is still unverified.

### Scope delivered
Purchase draft create/edit with live totals, supplier and product selection, line discounts (percent or amount), tax-exclusive and tax-inclusive pricing with tax snapshots, optional approval workflow (submit / approve / return to draft / cancel), posting (gap-free number, stock-in at net cost, weighted average cost, audit, one transaction), voiding through compensating `reversal` movements, purchase list with search and status filter, purchase detail with workflow actions, supplier payable on the supplier detail screen, schema v4 with database-level immutability of posted documents, central `DocumentStatus`, `Discount` value object, `DocumentSequenceRepository`.

### Verified in the authoring sandbox (Dart 3.13.7; no Flutter SDK, no pub.dev; stand-in packages for equatable/bloc/bloc_test/flutter_test)
- **319 tests executed, 0 failed** across all 24 test files that do not need Flutter or Drift (73 new in this phase): status transitions, `Discount`, document numbers, line calculator (exclusive/inclusive/discount/rounding/free/100%/large amounts), `SavePurchaseDraft`, `PostPurchase` (stock, WAC, tax excluded from cost, numbering, double-post rejection, archived product/supplier, tampered totals, rollback on audit and stock-write failure, reconciliation), approval workflow, `VoidPurchase` (restores stock and average cost, rejected when stock was used, all-or-nothing across lines, rollback), supplier payable, purchase BLoC / detail cubit / form cubit.
- Mutation checks: costing stock at `total` instead of `net` fails 2 tests; removing the posting status update fails 14.
- `dart format` parses every file; `tool/check_imports.dart`: dependency rules OK; strict `dart analyze` clean on all purchases domain/BLoC code, fakes and their tests.

### NOT verified (needs Flutter SDK + pub.dev)
- **Drift code generation: `app_database.g.dart` in the project is stale (v3) and must be regenerated** (`dart run build_runner build --delete-conflicting-outputs`). Nothing importing Drift compiled here: the new tables, `DriftPurchaseRepository`, `DriftDocumentSequenceRepository`, mapper, `DriftSettingsRepository` additions.
- Written but **not executed**: `test/core/database/purchase_schema_test.dart` (constraints + triggers), the 3 -> 4 migration test and the updated 1 -> 2 / 2 -> 3 simulations, `test/data/purchase_flow_test.dart` (real SQLite: post/void/rollback/numbering/search/payable), DI test additions, and `purchase_pages_test.dart` (widget tests). The pages, router wiring and DI registration have not been compiled.
- Running the app on a device.

### Known risks for the first real run
- SQL trigger and CHECK syntax in `schema_extras.dart` / the table classes was written from memory of SQLite; `purchase_schema_test.dart` is the quickest way to confirm it.
- `Migrator.createTable` plus the existing simulation approach: if Drift's `createTable` is not `IF NOT EXISTS`, the simulations rely on the dropped tables (done).
- The DB error mapper classifies trigger aborts as `DatabaseFailure` and CHECK/FK as `ValidationFailure`; the schema tests assert exactly that.
- Widget tests use dropdown/date/bottom-sheet interactions; finder tweaks may be needed.
- `DropdownButtonFormField.initialValue` requires a recent Flutter (already used elsewhere in the project).

### Acceptance criteria (Phase 4)
- Posting increases stock correctly; draft purchases do not change stock; totals accurate; WAC correct; reversal restores inventory and average cost; operations transactional: **passed against fakes that emulate rollback; against SQLite: unverified (tests written).**
- Posted purchases immutable at the database level: **unverified (tests written).**

### Next
1. `dart run build_runner build --delete-conflicting-outputs`, `dart format .`, `flutter analyze`, `flutter test`, and send me the output.
2. Fixing Phases 1-4 together is the best use of the next step. Phase 5 (Sales) starts after that.


## Phase 5 — Sales and Billing
**Status:** code written; **partially verified**. Not marked complete. Phases 1-5 have still not been confirmed on a Flutter machine.

### Scope delivered
Sales draft create/edit with live totals, optional customer (walk-in sales), product selection with **stock-availability validation** (per line while editing, cumulative per product on save, authoritative at posting), line discounts, tax-exclusive/inclusive pricing with tax snapshots, optional approval workflow, **posting** (gap-free number `INV-000001`, stock-out at weighted average cost, audit, one transaction, negative stock impossible), **void through compensating reversal movements at the original cost**, sales list with search/status filter, detail screen with workflow actions, customer receivable on the customer detail screen, **invoice PDF generation and sharing** (`InvoiceLayout` -> `PdfInvoiceRenderer` -> share sheet), schema v5 with database-level immutability of posted sales.

Refactoring done along the way: `LineAmounts` and the line calculator moved to `shared/domain` (`LineCalculator`) and are used by purchases and sales alike (no duplicated money logic). New contracts: `InventoryRepository.movementsForSource`, `SettingsRepository.isSalesApprovalRequired/setSalesApprovalRequired/getBusinessProfile`.

### Verified in the authoring sandbox (Dart 3.14.0 from conda-forge; no Flutter SDK, no pub.dev; stand-in packages for equatable/bloc/bloc_test/flutter_test)
- **357 tests executed, 0 failed** across 24 runnable test files. New in this phase: 52 sales use-case tests (draft, availability, post, rollback, double-post, tax, approval, void at original cost, reconciliation, receivable), 24 sales BLoC/cubit tests (incl. walk-in, stock-aware line sheet, customer receivable), 8 invoice-layout/share tests, plus the moved line-calculator tests.
- `tool/check_imports.dart`: dependency rules OK. Strict `dart analyze` clean on the sales domain, sales BLoCs, settings domain and shared domain.

### NOT verified (needs Flutter SDK + pub.dev)
- **Run `dart run build_runner build --delete-conflicting-outputs`: `app_database.g.dart` is stale (v3) and must be regenerated** for the purchase and sales tables.
- **`pubspec.yaml` has two new dependencies, `pdf` and `share_plus`, with deliberately wide version ranges** because pub.dev was not reachable; `flutter pub get` will pick the latest compatible versions. `PdfInvoiceRenderer` and `SharePlusInvoiceFileSharer` were written from knowledge of those packages' APIs (`pw.TableHelper.fromTextArray`, `SharePlus.instance.share(ShareParams(...))`) and have **never been compiled**; adjust if a newer major changed them.
- Written but not executed: `sales_schema_test.dart` (constraints/triggers, walk-in NULL customer), the 4 -> 5 migration test and the updated older migration simulations, `test/data/sales_flow_test.dart` (real SQLite), `sales_pages_test.dart` (widgets), DI/router changes, and all new pages (`sales_page`, `sales_form_page`, `sales_detail_page`, `sales_line_sheet`). Nothing importing Flutter or Drift was compiled.
- Six test files print no result in my stand-in harness (`rounding_test`, `money_formatter_test`, `file_image_storage_test`, `customer_bloc_test`, `inventory_cubits_test`, `supplier_bloc_test`); they printed nothing before this phase either, so I treat them as unverified rather than passing.
- The existing router test was stale (it still expected Purchases to be a placeholder); I corrected it, unrun.

### Known issues / decisions
- Cost of goods sold is read from the stock ledger, not stored on the invoice line (single source of truth); Phase 9 profit reports will sum ledger `sale` movements. This differs from the earlier sketch in `workflows/sales.md`, which has been updated.
- Voiding does not yet check payments or returns; Phases 6 and 7 must add those guards.
- "Invoice preview" is the on-screen detail page; I did not add the `printing` package (not needed for share). Printing can be added later.
- PDF amounts use the currency code (for example `INR 1,180.00`) because the built-in PDF fonts lack the rupee sign; product names in non-Latin scripts need an embedded font.
- Business identity on the PDF comes from `business_profiles` (falls back to "My Business") until Phase 11 adds the settings screen; there is no UI to edit it yet.
- The customers detail screen depends on the sales domain (like suppliers on purchases): a presentation-level exception, domain layers stay acyclic.

### Acceptance criteria (Phase 5)
- Sales reduce stock correctly; drafts do not affect stock; insufficient stock rejected; invoice calculations correct; reversal restores stock; historical invoices unchanged after product edits: **passed against fakes that emulate rollback; against SQLite: unverified (tests written).**
- PDF matches invoice data: **content verified through `InvoiceLayout` tests; the rendered PDF itself is unverified.**

### Next
1. `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `dart format .`, `flutter analyze`, `flutter test`, and send me the output.
2. Fixing Phases 1-5 together is the best use of the next step. Phase 6 (Payments) starts after that.

---

## Phase 6 — Payments and Outstanding Balances

### Scope delivered
Payments received from customers and made to suppliers with partial payments and allocation to several invoices (oldest-first helper), unallocated credit with later allocation, payment methods (seeded, create/archive), refunds, reversals that keep the original record, derived invoice payment status, outstanding customer/supplier balances, and the screens for all of it. Sales and purchase voids are now refused while payments are allocated. See `docs/workflows/payments.md`.

### Files
- Domain: `features/payments/domain/**` (entities, `PaymentStatusCalculator`, `AllocationPlanner`, `InvoiceLedger`, `AllocationChecker`, `PartyDirectory`, use cases `RecordPayment`, `AllocatePaymentCredit`, `RecordRefund`, `ReversePayment`, `GetPartyBalance`, `GetOpenInvoices`, `CreatePaymentMethod`, `SetPaymentMethodArchived`); `shared/domain/services/invoice_payment_guard.dart`, `shared/domain/enums/invoice_kind.dart`.
- Data: 4 Drift tables, `kSchemaExtraStatementsV6`, schema v6 migration + seeding, `DriftPaymentRepository` (also the `InvoicePaymentGuard`), `DriftPaymentMethodRepository`, mapper.
- Presentation: `PaymentsBloc`, `PaymentFormCubit`, `PaymentDetailCubit`, `OutstandingCubit`, `PartyBalanceCubit`, `InvoiceSettlementCubit`, `PaymentMethodsCubit`; pages for history, form, detail, outstanding, methods; `PaymentStatusChip`, `PartyBalanceCard`, `InvoiceSettlementCard`.
- Modified: `VoidSale`/`VoidPurchase` (guard), DI, router (payment routes; cubits provided on sale/purchase/customer/supplier detail routes), sale/purchase/customer/supplier detail pages, router test, old migration tests (drop the new tables when simulating older versions), test wiring.

### Verified in the authoring sandbox (Dart 3.14.0, no Flutter SDK, no pub.dev; stand-in packages)
- **490 tests executed in the runnable files, 0 failures attributable to Phase 6.** New: 11 status/planner tests, 38 use-case tests (records, partial/multi-invoice, credit, over-allocation, idempotency, rollback, reversal, refunds, balances, void guard, methods), 22 BLoC/cubit tests. Two void-guard tests added to the sales and purchase suites.
- Mutation check: removing the outstanding-amount check, the refund credit check, or the "reverse refunds first" check each made tests fail.
- The v6 trigger SQL was executed against real SQLite (python `sqlite3`) with equivalent tables: over-allocation, sign rules, single reversal behaved as intended.
- Strict `dart analyze` is clean on the payments domain, payments BLoCs, shared domain and the new test fakes.

### NOT verified (needs Flutter SDK + pub.dev)
- Everything from earlier phases still applies: regenerate `app_database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`; it now needs the 4 payment tables), then `dart format .`, `flutter analyze`, `flutter test`.
- Written but not executed: `DriftPaymentRepository` and the mapper (compile unchecked), `payment_schema_test.dart`, `payment_flow_test.dart` (real SQLite end to end, including audit-failure rollback), the 5 -> 6 migration test, the payment widget tests, the pages, the router wiring and the DI test additions.
- The same stand-in-only failure (`product_bloc_test` "emits loading then empty") and six files without output as in Phase 5.

### Known issues / decisions to review
- Walk-in sales are not tracked by payments (no party to hold the balance); shown on the sale screen.
- `writtenOff` is declared but never produced.
- Credit allocation has no idempotency key (bounded, cannot over-allocate).
- Posted sales/purchases in a currency other than the configured one cannot be settled until Phase 11.
- A bare `GET payments` has no pagination (history is loaded in full); fine for a small business, revisit in Phase 12.

### Acceptance criteria (Phase 6)
- Partial payments, full payments, outstanding balances, reversal recalculation, derived status, no duplicate financial effect: **domain level verified by executed tests**; persistence and UI level **unverified until the Flutter run**.
- Phase 6 is **not** marked complete until the real `flutter test` run passes.

### Next
1. Run the commands above and send me the output; I will fix Phases 1-6 together.
2. Phase 7 (Returns) is delivered below; run the same commands for it.


## Phase 7 — Returns Management

### Scope delivered
Sales returns (select posted invoice, per-line quantity, reason, restock or not, cash refund or credit) and purchase returns (per-line quantity, stock out at average cost, supplier refund or credit); returns are numbered documents (`SRN-`/`PRN-`), append-only, idempotent and posted in one transaction. Return quantity can never exceed the eligible quantity; amounts add up exactly to the invoice line. Returns feed invoice outstanding/credit and party balances; invoices with returns cannot be voided. Screens: returns list, return form (with live preview), return detail, a "Returns" card on sale and purchase detail, and return rows on the settlement and balance cards. See `docs/workflows/returns.md`.

### Files
- Domain: `features/returns/domain/**` (`ReturnDocument`, `ReturnLine`, `ReturnInput`, `ReturnableInvoice`, `ReturnPlanner`, `ReturnableInvoiceLoader`, `PostReturn`, `ReturnRepository`); `shared/domain/services/invoice_return_lookup.dart`.
- Data: 4 Drift tables, `kSchemaExtraStatementsV7`, schema v7 migration, `DriftReturnRepository` (also `InvoiceReturnLookup`/`InvoiceReturnGuard`).
- Presentation: `ReturnsBloc`, `ReturnFormCubit`, `ReturnDetailCubit`, `InvoiceReturnsCubit`; `ReturnsPage`, `ReturnFormPage`, `ReturnDetailPage`, `InvoiceReturnsCard`.
- Modified: `OpenInvoice` (returned, returnRefunded, receivable, cashHeld, credit), `InvoiceLedger`, `PartyBalance`, `GetPartyBalance`, `VoidSale`/`VoidPurchase` (return guard), settlement and balance cards, sale/purchase detail pages, DI, router (`/more/returns`, `new`, `:kind/:id`), tests/fixtures, migration/app-database/router tests.

### Verified in the authoring sandbox (Dart 3.14.0, no Flutter SDK, no pub.dev; stand-in packages)
- New executed tests: 22 use-case tests (restock cost, damaged goods, partial returns summing exactly with tax, over-return, validation, idempotency, rollback on failed insert, refund limits, walk-in, archived method, purchase stock-out and shortage, void guards, ledger reconciliation) and 9 BLoC/cubit tests. Existing runnable suites re-run: no regressions (the earlier `product_bloc_test` failure was a flaw in my `flutter_test` stand-in and is fixed there).
- The generated v7 SQL was executed against real SQLite: append-only, posted-invoice, same-invoice, over-return (qty/net/tax), void-after-return and CHECK constraints behaved as intended.
- `dart analyze` clean on the returns domain/BLoCs, shared domain, payments/sales/purchases domain and the new test files; `tool/check_imports.dart`: dependency rules OK.

### NOT verified (needs Flutter SDK + pub.dev)
- Regenerate `app_database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`; four new tables), then `dart format .`, `flutter analyze`, `flutter test`.
- Written but not executed or compiled: `DriftReturnRepository`, the table definitions, all returns pages/widgets, router and DI changes, `return_schema_test.dart`, `return_repository_test.dart`, the 6 -> 7 migration test, edits to existing pages and cards.
- Not written: widget tests for the returns pages and a real-database end-to-end flow test (use-case level is covered with fakes; the Drift repository has its own round-trip test).

### Known issues / decisions to review
- Returns cannot be undone (ADR-032).
- Purchase return credit vs average cost: any difference is not tracked.
- A fully returned unpaid invoice shows payment status "paid" (nothing left to settle); the detail page shows the returned amount.
- Party balances still count only the configured currency (Phase 6 rule).
- Not-restocked sales returns leave the original cost of goods sold unchanged (goods treated as lost).

### Acceptance criteria (Phase 7)
- Quantities validated, inventory updated correctly, refunds/credits accurate, originals immutable, auditable: **domain level verified by executed tests; SQL rules verified against SQLite**; Drift/UI level **unverified until the Flutter run**. Phase 7 is **not** marked complete until the real `flutter test` run passes.

### Next
Run the commands above and send me the output; I will fix Phases 1-7 together before Phase 8 (Expenses). *(Phase 8 was then built on request before that run; see below.)*

## Phase 8 — Expenses Management

> Built on request while Phases 1-7 still await their first real `flutter test` run. Phase 8 therefore rests on code that has not been compiled against Flutter/Drift; treat everything marked unverified below as unconfirmed.

### Scope delivered
Expense categories (create, rename, archive/restore, search; 8 seeded defaults), expenses (draft → post → void, cancel draft, numbered `EXP-000001`), date, amount, optional tax (inclusive or exclusive, exempt-aware), payment method, payee, reference, notes, receipts (JPG/PNG/WebP/PDF attachments), expense history with search plus status, category and date-range filters (and a posted total of the filtered list), and an expense report (this/last month, last 30 days, this year, custom range, category filter; totals and per-category breakdown that add up exactly). Posted expenses are immutable and never deleted. See `docs/workflows/expenses.md`.

### Files
- Domain: `features/expenses/domain/**` — entities (`Expense`, `ExpenseCategory`, `ExpenseAmounts`, `ExpenseAttachment`, `ExpenseDraftInput`, `ExpenseSummary`, `ExpenseFilter`, `ExpenseReport`), contracts (`ExpenseRepository`, `ExpenseCategoryRepository`, `AttachmentStorage`), services (`ExpenseCalculator`, `ExpenseIntegrity`, `ExpensePeriod`), use cases (`SaveExpenseDraft`, `PostExpense`, `CancelExpense`, `VoidExpense`, `AddExpenseAttachment`, `RemoveExpenseAttachment`, `CreateExpenseCategory`, `UpdateExpenseCategory`, `SetExpenseCategoryArchived`); `core/utils/date_only.dart`.
- Data: tables `expense_categories`, `expenses`, `attachments`; `kSchemaExtraStatementsV8`; schema v8 migration and seeding in `AppDatabase`; `DriftExpenseRepository`, `DriftExpenseCategoryRepository`, `FileAttachmentStorage`, `expense_mapper.dart`.
- Presentation: `ExpensesBloc`, `ExpenseFormCubit`, `ExpenseDetailCubit`, `ExpenseCategoriesCubit`, `ExpenseReportCubit`; `ExpensesPage`, `ExpenseFormPage`, `ExpenseDetailPage`, `ExpenseCategoriesPage`, `ExpenseReportPage`, `ExpenseCategoryDialog`; shared `DocumentStatusChip`.
- Modified: `app_database.dart` (schema 8, tables, seeding, upgrade), `schema_extras.dart`, `tables.dart`, DI (`register_repositories/usecases/blocs`), router and `route_names.dart` (Expenses is no longer a placeholder), docs.
- Tests added: `expense_calculator_test`, `expense_use_cases_test`, `expense_blocs_test`, `expense_pages_test`, `expense_schema_test`, `expense_flow_test`, `test/support/expense_fakes.dart`; updated `test_locator`, `migration_test`, `app_database_test`, `app_router_test`, `injection_test`.

### Verified in the authoring sandbox (Dart 3.14.0 from conda-forge; no Flutter SDK, no pub.dev; stand-in packages for equatable/bloc/flutter_test)
- **Executed:** 77 tests pass — calculator and period tests (12), use-case tests (41: validation, tax inclusive/exclusive/exempt, date rules, double post, numbering gaps, rollback on failed write and failed audit, tampered totals, archived choices, void rules, attachments incl. file cleanup, category rules, report totals/ranges/voided exclusion), BLoC/cubit tests (24: filters, live preview, save/post, post-refused-after-save, archived category re-pick, detail actions, categories, report periods).
- Three mutations of the rules (skip integrity check, skip posted-status check, allow future dates) were each caught by a test. A fourth (skip the void status check in the use case) survives at use-case level because the repository's guarded update also rejects it; that rule is enforced there and in SQL.
- The generated v8 SQL (indexes, constraints, triggers) was executed against real SQLite with equivalent table definitions: duplicate names, number uniqueness, immutability of posted rows (including a void that tries to change an amount), no delete, attachment open/closed rules and CHECK constraints behaved as intended.
- `dart analyze` (strict casts and raw types) is clean on the expenses domain and BLoCs and on the new runnable tests; `tool/check_imports.dart`: dependency rules OK; every new file passes `dart format`.

### NOT verified (needs Flutter SDK + pub.dev)
- Regenerate `app_database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`; three new tables, schema v8), then `dart format .`, `flutter analyze`, `flutter test`.
- Written but **not compiled or executed**: the three Drift table definitions and the `AppDatabase` edits, `DriftExpenseRepository`, `DriftExpenseCategoryRepository`, `FileAttachmentStorage`, the mapper, all expenses pages/widgets, router and DI edits, `expense_pages_test.dart`, `expense_schema_test.dart`, `expense_flow_test.dart`, the 7 -> 8 migration test and the edits to older migration tests.
- Not done: attachment preview/opening (files are listed with name and size only; no extra package was added), PDF/CSV export of the expense report (Phase 9 covers exports), approval workflow, recurring expenses, expense-specific dashboard tiles (Phase 9).

### Known issues / decisions to review
- Attachments are managed on the detail page (save first, then attach) rather than inside the form.
- Posted expenses cannot be edited at all (void and re-enter), including notes.
- Report sums only the configured currency and reports the count of others (same rule as party balances).
- Expense date may be at most one day ahead; this is a fixed rule, not a setting.
- `DocumentStatusChip` now exists in `shared`; the purchase, sales and returns screens still use their own copies (cleanup candidate).
- Existing files in the project are not formatted with the Dart 3.14 formatter (the router and DI files showed pending changes before my edits); I formatted only the files I created.

### Acceptance criteria (Phase 8)
- Expense CRUD works, totals are correct, validation works, reports reflect recorded expenses: **domain level verified by executed tests; SQL rules verified against SQLite**; Drift/UI level **unverified until the Flutter run**. Phase 8 is **not** marked complete until the real `flutter test` run passes.

### Next
Run the commands above on Phases 1-8 and send me the output so I can fix whatever breaks before Phase 9 (Dashboard and Reports).



## Phase 9 — Dashboard and Reports

> Built on request while Phases 1-8 still await their first real `flutter test` run. Phase 9 therefore rests on code that has not been compiled against Flutter/Drift.

### Scope delivered
Dashboard (period figures, stock and balance alerts, sales-vs-purchases chart, recent documents, period chips incl. custom range, pull to refresh) replacing the placeholder, and eleven reports (sales, purchases, inventory, stock movements, low stock, product performance, customer outstanding, supplier outstanding, payments, expenses, profitability) with period, customer/supplier/product filters, `fl_chart` bar charts and CSV export. Assumptions for gross profit, expenses and cash are documented in `docs/workflows/reports.md` and printed on the reports. No schema change.

### Files
- Shared: `shared/domain/value_objects/date_range.dart` (`DateRange`).
- Domain `features/reports/domain/**`: `ReportKind`, `ReportPeriod`, `ReportFilter`, `ReportDocument` model (typed cells, metrics, tables, charts), figure types, `ReportRepository`, `ReportExporter`, `ProfitFigures`, `TimeBuckets`, `ReportCsv`, document builders (register, stock, finance), `ReportFilterOptions`, use cases `BuildReport`, `GetProfitFigures`, `ExportReportCsv`. `features/dashboard/domain/**`: `DashboardSnapshot`, `GetDashboard`.
- Data: `DriftReportRepository`, `report_queries.dart` (22 SQL constants), `SharePlusReportExporter`.
- Presentation: `DashboardBloc`, `ReportBloc` (+ events); `DashboardPage`, `ReportsPage`, `ReportPage`; `ReportView`, `TrendBarChart`, `PeriodChips`, `ReportFormatters`.
- Modified: `app_router.dart` (dashboard gets its bloc; `/more/reports` and `/more/reports/:kind`, Reports no longer a placeholder), `route_names.dart`, DI (`register_repositories/usecases/blocs`), `pubspec.yaml` (+`fl_chart`, wide unverified range), `test_locator.dart`, `injection_test.dart`.
- Tests added: `report_domain_test` (28), `report_use_cases_test` (20), `report_blocs_test` (16), `report_pages_test` (6 widget tests, not executed), `test/support/report_fakes.dart`.

### Verified in the authoring sandbox (Dart 3.14.0, no Flutter SDK, no pub.dev; stand-in packages for equatable/bloc/flutter_test)
- **64 new tests executed, 0 failed** (domain maths, period/bucket edge cases, CSV rules, builders, use cases, BLoCs). Six mutations (returns not subtracted, expenses not deducted, formula-injection guard removed, bucket matching removed, expenses at gross instead of net, credit balances counted as receivable) were each caught.
- **All 22 report SQL queries were executed against real SQLite** (python `sqlite3`, tables with the same column names as the Drift definitions) with a fixture covering voided/draft/out-of-range/other-currency documents, reversed payments, restocked and unrestocked returns, customer/supplier/product filters and the ledger date boundary; every expected figure matched.
- `tool/check_imports.dart`: dependency rules OK. Strict `dart analyze` (strict-casts, strict-raw-types) clean on the reports/dashboard domain and BLoCs, `DateRange`, and the new runnable tests and fakes. All new files pass `dart format`.
- Regression run of every test file that can run without Flutter/Drift: 646 tests passed. 12 failures sit in five older files (`customer_bloc`, `supplier_bloc`, `inventory_cubits`, `product_bloc`, one `expense_use_cases` test); the messages point at my minimal stand-in packages (listener closing a synchronous broadcast stream, `Iterable` vs `List` equality), not at project code. Treat them as unverified until the real run.

### NOT verified (needs Flutter SDK + pub.dev)
- Everything that imports Drift or Flutter: `DriftReportRepository` (variable binding, `QueryRow.read`), `SharePlusReportExporter`, all pages and widgets, router and DI edits, `report_pages_test`, the `injection_test` additions.
- **`fl_chart` code was written from memory of its API** (`BarChart`, `BarTouchTooltipData`, `FlTitlesData`) and `pubspec.yaml` has a wide version range; a major release may need small edits.
- Regenerate `app_database.g.dart` as for earlier phases (no schema change in Phase 9).
- The older phases remain unrun, so none of this can be marked complete.

### Known issues / decisions to review
- Operating result uses expenses **excluding tax** (tax assumed recoverable); the alternative is the amount paid.
- CSV only; PDF export not implemented.
- Tables read at most 1000 rows; the screen draws at most 100.
- Stock movement days are UTC days.
- Dashboard does not auto-refresh when data changes on another tab.
- Outstanding reports loop over parties (N+1 queries).
- The Phase 8 `ExpensePeriod` and the new `ReportPeriod` are near duplicates (cleanup candidate).
- Running `dart format .` with the sandbox's Dart 3.14 touches many older files; only files edited for this phase were left formatted.

### Acceptance criteria (Phase 9)
- Dashboard reflects database data, report totals reconcile, report calculations tested: **domain level and SQL verified by executed tests**; date filtering **verified in SQL and BLoC tests**; charts show correct values: **bucket sums verified, rendering unverified**; empty states: **BLoC verified, widgets unverified**.
- Phase 9 is **not** marked complete until the real `flutter test` run passes.

### Next
Run `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `dart format .`, `flutter analyze`, `flutter test` and send me the output; fixing Phases 1-9 together is the best next step before Phase 10 (Backup and Restore).


### Phase 9 follow-up: richer dashboard
Added a line chart (running net sales), two donuts (expenses by category, stock health), ranked bars (where the money went, top products, cash and balances) and four tiles (gross margin, average sale, returns, tax collected). New data: `DashboardSnapshot.topProducts`, `trendChart`, `averageSale`, `taxCollected`, `healthyStockCount`; `TimeBuckets.cumulative`. Executed tests: 29 + 22 + 16 pass (report domain, use cases, BLoCs). The new chart widgets (`dashboard_charts.dart`, `fl_chart` LineChart/PieChart) and the dashboard layout are **not compiled or run**; "healthy" stock is products with stock minus low-stock ones, so archived products holding stock can slightly inflate it.


---

## Phase 10 — Backup, Restore and Data Protection

> Built on request while Phases 1-9 still await their first real `flutter test` run. Everything that imports Drift, Flutter, `file_picker`, `share_plus` or `path_provider` is **uncompiled**.

### Scope delivered
Backup creation (consistent `VACUUM INTO` snapshot, integrity gate, ZIP with manifest and SHA-256, post-write verification, history incl. failures), export (share sheet / save to device, checksum re-checked first), stored-copy deletion, strict restore validation (zip-slip, links, unknown/missing/extra entries, size limits, checksums, compatibility, integrity), confirmation dialog, restore with safety backup, rename-based swap, rollback, crash journal and start-up recovery, app runtime restart (`InventrixRuntime`/`InventrixHost`), schema v9 (`backup_history`), Backup screen. See `docs/workflows/backup_restore.md`.

### Files
- Domain `features/backup/domain/**`: entities, `ArchivePathRules`, `ManifestCodec`, `RestoreCompatibility`, `BackupNaming`, journal codec, contracts, use cases (`CreateBackup`, `ListBackups`, `DeleteStoredBackup`, `ExportBackup`, `PrepareRestore`, `DiscardStagedBackup`, `RestoreBackup`, `RecoverInterruptedRestore`, `ReconcileRestoreJournal`).
- Data: `ZipBackupPackager`, `FileRestoreSwapper`, `FileRestoreJournalStore`, `AppStorageLocations` (all plain `dart:io`), plus Drift/Flutter-dependent `DriftBackupHistoryRepository`, `DriftDatabaseSnapshotter`, `SqliteDatabaseInspector`, `PlatformBackupExporter`, table `backup_history`.
- App: `app/runtime/*` (runtime, host, startup failure screen, unavailable runtime), `register_backup.dart`; modified `bootstrap.dart`, `app.dart`, `injection.dart`, router, `schema_extras.dart`, `app_database.dart` (v9), `tables.dart`, `app_constants.dart`, `pubspec.yaml` (+`archive`, `crypto`).
- Presentation: `BackupBloc`, `BackupPage`, `RestoreConfirmationDialog`.
- Tests added: `zip_backup_packager_test` (9), `backup_use_cases_test` (24), `backup_bloc_test` (6), `backup_page_test`, `backup_history_repository_test`, 8 -> 9 migration test, DI test; `support/backup_fakes.dart`; `test_locator.dart` extended; `app_database_test` now expects v9.

### Verified in the authoring sandbox (Dart 3.14.0; real `archive` 4.7.1 and `crypto` 3.0.5 sources; stand-ins for `equatable`, `logging`, `flutter_test`)
- **33 tests executed, 0 failed**: packager round trip, tampered content, `../` traversal, absolute/backslash/unknown entries, extra entry not in manifest, non-ZIP, foreign manifest, non-empty staging; backup creation, name collisions, damaged-database refusal, export checksum check; restore confirmation gate, data + attachment replacement, safety backup content, swap while closed, migration failure, safety-backup failure, shutdown failure, start failure rollback, refused swap, interrupted-swap recovery, completed-restore reconciliation (once), no-op rollback. All on **real files** in temp folders.
- The tests found and I fixed two real bugs: a `File` object interpolated into a path (`'$live...'`) and a rollback after a refused swap that could have moved an unrelated leftover over live data.
- `dart analyze` clean on `features/backup/domain`, `features/backup/data/services` (file-based classes), the new tests and fakes. `tool/check_imports.dart`: dependency rules OK.

### NOT verified (needs Flutter SDK + pub.dev)
- Regenerate `app_database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`; new table `backup_history`, schema v9), then `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`.
- Uncompiled: the `BackupHistory` table and `AppDatabase` edits, `DriftBackupHistoryRepository`, `DriftDatabaseSnapshotter` (`VACUUM INTO ?` with a bound parameter), `SqliteDatabaseInspector` (`sqlite3` 2.x `open`/`select`/`close`), `PlatformBackupExporter` (`FilePicker.saveFile`, `SharePlus` `ShareResultStatus` — written from memory), runtime/host/bootstrap, DI, router, BLoC, pages. Tests written but not run: `backup_history_repository_test` (incl. a real `VACUUM INTO`), the 8 -> 9 migration, `backup_bloc_test`, `backup_page_test`, DI test.
- **Never exercised on a device**: that `PRAGMA database_list` returns the real file path through Drift's isolate, that renaming the database while Drift's connection is closed works on Android/iOS, the share/save flows, and the full restart (`resetDependencies` → `configureDependencies`). Test a real restore on a device before relying on it.
- `pubspec.yaml`: `archive`/`crypto` ranges are wide and unverified against pub.dev.

### Known issues / decisions to review
- Product photos are part of the backup (added beyond the spec's wording); layout documented.
- `AppConstants.appVersion` is a constant and must be kept in step with `pubspec.yaml`.
- No automatic or scheduled backups yet; no pruning of old backups or safety copies (user deletes them on the screen).
- The restore history rows are written on the next start (journal), so the history briefly lacks them.
- Large databases are held in memory during verification/save-as (see workflow doc).
- I ran the sandbox `dart format` over `lib/app`, `lib/features/backup` and `test/`; it may have reformatted older files with the Dart 3.14 style.

### Acceptance criteria (Phase 10)
- Archive valid, checksums validated, failed restore does not destroy data, path traversal rejected: **verified by executed tests on real files**.
- Database integrity verification, `VACUUM INTO` snapshot, restore of a real Drift database, restart of the app, backup surviving uninstall when exported: **unverified until the Flutter run / device test**.
- Phase 10 is **not** marked complete.

### Next
Run `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `dart format .`, `flutter analyze`, `flutter test`, then a manual restore on a device, and send me the output; fixing Phases 1-10 together is the best next step before Phase 11 (Settings).

## Phase 11 — Settings and Business Configuration

> Built on request while Phases 1-10 still await their first real `flutter test` run. Everything that imports Drift, Flutter, `file_picker`, `path_provider`, `intl` or `pdf` is **uncompiled**.

### Scope delivered
Business profile (name, address, phone, e-mail, tax number, logo; logo printed on invoice PDFs), currency and decimal places with a history-protecting lock, date style and number style applied app-wide, light/dark/system theme, tax rate management (add, edit, archive/restore, default rate and default "price includes tax" for new products), configurable document prefixes and digit padding with "set next number", sales/purchase approval switches, default payment method, backup reminder banner. No schema change. Details and rules: `docs/workflows/settings.md`.

### Files
- New domain: `features/settings/domain/entities/{app_preferences,business_profile_input,currency_option,money_lock,numbering_settings,setting_keys}.dart`, repositories `{preferences,business_profile,currency,numbering}_repository.dart` + `logo_storage.dart`, use cases `{save_business_profile,change_currency,update_preferences,save_numbering,manage_tax_rates}.dart`; shared `document_kind.dart`, `value_objects/display_formats.dart`; `features/backup/domain/services/backup_reminder.dart`.
- New data: `drift_{preferences,business_profile,currency,numbering}_repository.dart`, `file_logo_storage.dart`.
- New presentation: `SettingsCubit`/`SettingsState`, `TaxRatesCubit`, pages `settings`, `business_profile`, `regional_settings`, `numbering`, `tax_rates`; `TaxRateFormDialog` moved here from products and extended for editing.
- New core: `core/formatters/{display_formats,date_formatter,number_grouping}.dart`.
- Modified: `MoneyFormatter` (own digit grouping, styles), date helpers (sales/purchases/expenses/reports/stock detail/backup) now use `DateFormatter`; `DocumentSequenceRepository.nextNumber(kind)` (Drift + fake) replaces `prefix + sequence` in `PostSale`, `PostPurchase`, `PostExpense`, `PostReturn`, `RecordPayment`, `RecordRefund` (obsolete `*Numbering.prefix/sequenceKey` constants removed); `TaxRateRepository` (+`update`, `isInUse`, `nameExists(excludingId)`); product/payment/expense form cubits and `PaymentMethodsCubit` read defaults; `InvoicePdfRenderer.render(..., logo:)`; `ShareInvoicePdf` (+`LogoStorage`); `InventrixApp` (theme + `FormatRefresher`), runtime/host (settings loaded before the first frame); router (`/more/settings/...`), DI; Backup page (reminder).

### Tests
- **Executed in the sandbox (Dart 3.14.0, stand-ins for `equatable`, `flutter_test`, `bloc`, `intl`), 63 new tests, 0 failed:** `document_number_test` (6), `display_formats_test` (9), `backup_reminder_test` (3), `settings_use_cases_test` (26), `numbering_posting_test` (4, through the real `PostPurchase`), `settings_cubits_test` (15). All previously runnable tests (29 files) still pass; the original project had 24 runnable files, the extra ones are `money_formatter_test` (needs the `intl` stand-in) and the new ones.
- SQL (money-lock query, counter upsert with `MAX`, in-use query) executed against real SQLite via Python, not through Drift.
- The tests found and I fixed one bug: saving an unchanged tax rate still wrote and audited because `updatedAt` made the objects differ.
- **Written, not run (need Flutter/Drift):** `test/data/settings_repositories_test.dart`, `test/data/file_logo_storage_test.dart`, `test/features/settings/settings_pages_test.dart`, the new settings case in `test/app/di/injection_test.dart`.

### NOT verified (needs Flutter SDK + pub.dev)
- `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs` (no table changes, so the existing `app_database.g.dart` should still be right), `dart format .`, `flutter analyze`, `flutter test`.
- Uncompiled: all Drift repositories above, `FileLogoStorage` (`path_provider`, `logging`), pages, `FormatRefresher` (marks the element tree dirty; never run), `pw.MemoryImage` logo decoding, `FilePicker.pickFiles` for the logo (same call as the product photo).
- Never seen on a device: theme switching, live format refresh on open screens, logo on a real invoice PDF.

### Known issues / decisions to review
- The currency is effectively fixed once you add prices, stock or post an invoice; there is no "start over" tool. This is deliberate (see `settings.md`) but may feel strict.
- `FormatRefresher` redraws the tree after a style change; screens that cache formatted text in state (not in `build`) would still show the old style until reloaded.
- Prefix rule "must not end in a digit" rejects values like `INV2`.
- A logo picked and then abandoned (form closed without saving) stays as an orphan file in `product_images/`.
- No scheduled backups, only a reminder. The legacy `locale` setting row is no longer used.
- I ran `dart format` with Dart 3.14 on the files I edited; they may differ in style from your formatter. Files I did not edit were left untouched.
- Dependency rule check (`tool/check_imports.dart`): OK.

### Acceptance criteria (Phase 11)
- Document numbers stay unique and prefix changes never alter issued numbers; counters move forward only; currency change is refused when history would break; tax-rate edits protected: **verified by executed tests** on fakes (+ SQL on real SQLite).
- Settings persist across restarts, theme/format application, currency formatting consistency, logo on PDF: **unverified until the Flutter run / device test**.
- Phase 11 is **not** marked complete.

### Next
Run `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test` and send me the output; fixing Phases 1-11 together is the best next step before Phase 12 (QA and release).

## Redesign Phase 5 (screens): in progress

Dashboard, Products, Units, Categories, Inventory, Sales, Purchases, Customers, Suppliers and Payments restyled; the other groups are listed in `docs/redesign/phase5_screens.md`. Not compiled or run.
