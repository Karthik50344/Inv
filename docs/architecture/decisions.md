# Architecture Decision Records & Risks

## ADR-001 Money as integer minor units (no `decimal` package)
Prices, totals, tax, discounts are `int` minor units. Intermediate products (price × quantity) use 64-bit ints: `minor × milliQty` stays well under 9.2×10^18 for realistic values; overflow is guarded in `Money`/`Quantity` operations (throws a domain error instead of wrapping). Rounding: **half away from zero**, applied once per line, never on running totals.

## ADR-002 Quantity as scaled integer (scale 10^3)
`Quantity(milli)`. `Unit.decimalPlaces` ∈ {0,1,2,3} limits entry (pieces=0, kg=3). Operations between different units are rejected (no implicit conversion in v1).

## ADR-003 Weighted Average Cost via value tracking
Balance stores `quantity_on_hand` and `inventory_value_minor`. Average cost is *derived* = value / quantity.
- Purchase / stock-in: `qty += q`, `value += cost` (line net cost, excl. recoverable tax).
- Sale / stock-out / purchase-return: `cogs = round(value × q / qty)`; `value -= cogs`; `qty -= q`. If `q == qty`, `cogs = value` (residual rounding is absorbed; value returns to exactly 0).
- Sales-return restock: re-enters at the **original sale's COGS per unit** (stored on the movement), not the current average.
- Purchase return: reduces value at current average.
- Positive stock adjustment / opening stock: needs a unit cost (default current average, else last purchase price, else entered by user).
Every movement stores `total_cost_minor` and `unit_cost_minor_snapshot` so the ledger can rebuild balances.

## ADR-004 Transaction boundary
`TransactionRunner.run(action)` in domain; Drift implementation wraps `database.transaction`. Drift propagates the transaction via Zones, so repositories called inside share it. Use cases revalidate every rule inside the transaction (re-read stock, status) — UI validation is advisory only.

## ADR-005 Document numbers
Drafts have **no number**. A number is allocated from `document_sequences` inside the same transaction as the first transition out of draft, giving gap-free sequences per (document type, prefix). Unique index on `(document_type, document_number)`.

## ADR-006 Status model
One enum `DocumentStatus`: `draft, created, pendingApproval, approved, authorized, posted, cancelled, voided`.
- v1 workflow: `draft → posted` (approvals off) or `draft → pendingApproval → approved → posted` (approvals on).
- `created`, `authorized` are reserved in the enum and transition table but not reachable in v1 (avoids dead UI states).
- `cancelled` = abandoned **before** posting. `voided` = **posted** document reversed by compensating entries.
- Only `posted` affects ledgers.

## ADR-007 Payment status is derived
Computed from invoice total, allocations, reversals, refunds, due date. Never persisted (avoids stale state). A query service supplies it to lists.

## ADR-008 Backup snapshot
Use `VACUUM INTO '<temp>.sqlite'` for a transactionally consistent copy (SQLite ≥ 3.27, bundled via `sqlite3_flutter_libs`). Never copy the live `.sqlite`/`-wal` files.

## ADR-009 Idempotency
Posting guarded by status check inside the transaction + unique constraint on `stock_movements(source_type, source_id, source_line_id, movement_type)`. Payments carry a unique `idempotency_key`.

## ADR-010 Locale defaults
Default currency INR (configurable), default locale `en_IN` (lakh/crore grouping via `intl`), date format configurable. Nothing hardcodes INR or any country's tax rules.

## Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | Package versions cannot be verified in this environment (pub.dev unreachable, no Flutter SDK) | Phase 1 adds deps via `flutter pub add`, records resolved versions in `pubspec.lock` and `setup.md` |
| R2 | Spec's package list omits `crypto` (SHA-256), `drift_flutter`/`sqlite3_flutter_libs`, `logging`, `flutter_bloc`, `json_annotation`/`freezed_annotation` | Added below; **needs your approval** |
| R3 | Rounding drift in WAC | ADR-003 value tracking + property-style tests |
| R4 | Partial writes corrupting ledger | Single transaction boundary + reconciliation use case + tests |
| R5 | Restore swaps DB while app holds connections | Close DB, swap, re-init DI — integration test |
| R6 | Schema churn before release | Drift schema dumps from Phase 1 + `SchemaVerifier` migration tests |
| R7 | Tax rules vary by jurisdiction | Configurable rates/groups only; legal validation before release |
| R8 | Data lives only on device | Prominent backup warning, backup reminders |
| R9 | iOS build unverifiable without macOS | Phase 12 gate requires macOS check; keep platform code minimal |

## Dependency list (proposed)

**Runtime:** flutter_bloc, bloc, equatable, go_router, get_it, drift, drift_flutter, sqlite3_flutter_libs, freezed_annotation, json_annotation, intl, fl_chart, pdf, printing, file_picker, share_plus, path_provider, path, archive, crypto, uuid, logging.
**Dev:** build_runner, drift_dev, freezed, json_serializable, bloc_test, mocktail, flutter_test, integration_test, very_good_analysis.
**Deferred:** mobile_scanner (future phase). **Excluded:** `decimal` (ADR-001).
Product images/logo use `file_picker` + copy into app documents dir (no `image_picker` unless you want camera capture).


## Phase 1 addenda
- **ADR-011 Dependencies are added per phase.** Phase 1 adds only what it uses (see `development/setup.md`); `flutter_bloc`, `equatable`, `crypto`, etc. arrive with the phase that needs them.
- **ADR-012 Only Money and Quantity in Phase 1.** `TaxRate`, `Discount`, `Percentage`, `InvoiceNumber`, `ProductSku`, `StockLevel`, `DateRange` are created in the phase that first uses them, to avoid unused abstractions. Money already exposes basis-point helpers for tax and discounts.
- **ADR-013 Localized formatting** (`intl`) lives in a presentation/core formatter, not in domain `Money`; `Money.toPlainString()` is the pure-Dart representation.
- **ADR-014 Failure transport.** `FailureException` lets a use case abort a transaction with a typed `Failure`; `guardDatabase` converts it back to a failed `Result`.


## Phase 2 addenda
- **ADR-015 Archive instead of delete; archiving is blocked while active products depend on a category or unit.** Hard deletion is not offered; the database also uses `ON DELETE RESTRICT`. This satisfies "prevent invalid deletion when products depend on a category" without orphaning references.
- **ADR-016 Unit precision rule.** Increasing a unit's decimal places is always allowed; reducing it is rejected once any product (archived or not) uses the unit. Reorder levels (and later stock quantities) must fit the unit's precision. Cross-unit arithmetic remains rejected at the value-object level.
- **ADR-017 Units live in the products feature**, tax rates and currency settings in a minimal `settings` feature, and `CurrencyConfig` in the shared kernel. This keeps `products -> settings` acyclic per `feature_dependencies.md`.
- **ADR-018 Validation lives in the domain.** Forms send raw text (`ProductDraft`, `PartyDraft`); `ProductValidator` / `validatePartyDraft` parse money and quantities with the active currency and unit precision. Pages add only instant "required" checks. Uniqueness is pre-checked for friendly field errors and enforced by the database as the safety net.
- **ADR-019 SKUs** are upper-cased and validated (`A-Z 0-9 . _ / -`, max 40). A blank SKU on create becomes `P-000001`, `P-000002`, ... based on the highest existing generated number.
- **ADR-020 Product images** are copied into app storage and referenced by relative path (the iOS container path can change between updates); JPG/PNG/WebP up to 10 MB.
- **ADR-021 Customers and suppliers share validation** (`PartyDraft`/`PartyFields`) but remain separate features, entities, tables and screens; their code is generated from one template so behaviour cannot drift.
- **ADR-022 Simple master data uses Cubits that return the save `Result`** (categories, units) so dialogs can show field errors inline; lists use a BLoC with sequential event processing (customers, suppliers, products).
- **Not in Phase 2:** editing/archiving tax rates (Phase 11), barcode scanning (future), stock-aware unit checks (Phase 3 adds an inventory guard without making products depend on inventory).


## Phase 3 addenda
- **ADR-023 Transaction pattern.** Use cases that change several records run read -> validate -> write inside `TransactionRunner.runResult`. Repositories return `Result` (they do not throw), so steps are unwrapped with `Result.getOrThrow()`; a failed step aborts and rolls back and the original typed `Failure` is returned. `TransactionRunner` gained `runResult` for this.
- **ADR-024 Opening stock** is allowed once, only before any other movement, so the ledger always begins with an auditable opening entry.
- **ADR-025 Manual stock in/out are adjustments** with a mandatory reason. Stock-in cost: given unit cost, else the current average cost, else the product's purchase price. Using the (rounded) per-unit average times the quantity can move the average by at most half a minor unit per unit; documented and accepted.
- **ADR-026 Status rules:** `out` = 0; `low` = positive stock at or below a positive reorder level. Archived products are excluded from counts but their value stays in the total.
- **ADR-027 Reconciliation never changes data by itself.** Repair is a separate confirmed action, audited per product, and refuses negative ledgers.
- **ADR-028 Audit log** (`audit_logs`, schema v3) is append-only and written inside the same transaction as the action.
- **ADR-029 Inventory reads products through the `ProductRepository` contract**, never through the products feature's data layer (dependency rule 8).
- **ADR-030 Unit precision guard.** The Phase 2 rule (precision cannot be reduced once any product uses the unit) already guarantees stock quantities keep fitting; no inventory dependency was added to `products`.
- **Not in Phase 3:** stock transfers (no multi-location), batch/serial tracking, stock-take sheets, barcode scanning, purchase/sale postings (Phases 4-5).

## Phase 7 addenda
- **ADR-031 A return is a credit note, its own document.** Not an edit of the invoice and not a payment. It lowers what is owed; cash handed back is recorded on the return itself (`refund_*`), not as a `payments` row, so payment history stays "money for invoices" and a return is traceable as one document.
- **ADR-032 Returns are final.** No void/undo in Phase 7. An invoice with returns cannot be voided (use case + trigger). Reasoning: undoing a return would need its own reversal of stock, credit and cash; deferred until there is a real need.
- **ADR-033 `returns` depends on `payments`; `payments` sees returns through shared contracts** (`InvoiceReturnLookup`, `InvoiceReturnGuard` in `shared/domain/services`), implemented by the returns data layer. Keeps the graph acyclic (same pattern as `InvoicePaymentGuard`).
- **ADR-034 Proportional amounts with a completing remainder** (see `workflows/returns.md`): returns of a line add up exactly to the line; all in one pure `ReturnPlanner` shared by preview and posting.
- **ADR-035 Cash refund capacity** is money paid beyond what remains owed; the rest stays as credit. Walk-in returns always hand the whole value back.
- **ADR-036 Sales returns restock at the original sale cost; purchase returns leave at the current average cost.**
- **ADR-037 Return repository uses plain SQL** (`customSelect`/`customInsert`) for two table pairs of one shape, so it does not depend on generated row classes.
- **ADR-038 Expenses are standalone numbered documents** (`EXP-`), not payments: they carry their own payment method and are not allocated to invoices. Statuses `draft → posted → voided` (plus `cancelled` for discarded drafts); no approval step until Phase 11 configures approvals.
- **ADR-039 Posted expenses are immutable**, enforced by a trigger; correction means void + re-enter. Only posted expenses count in reports, by expense date, at the amount paid (tax included).
- **ADR-040 Receipts are evidence.** Attachments can be added to draft or posted expenses and removed only from drafts. They use a generic `attachments` table (`owner_type`/`owner_id`, relative paths) with trigger-enforced rules so other owners can reuse it.
- **ADR-041 Expense snapshots at posting.** Category and payment-method names are refreshed when posting and then frozen; a draft whose category or method was archived must be re-pointed before it can be posted.

- **ADR-042 Settings keep history intact (Phase 11).** Currency and decimals are locked while amounts without their own currency exist or invoices are posted; document prefixes are read at posting time, must not end in a digit and counters only move forward; tax-rate percentages freeze once used; display formats are presentation state (`DisplayFormats`) refreshed by `FormatRefresher`. The business logo is stored in the already-backed-up `product_images/` folder instead of a new archive folder. `DocumentSequenceRepository.nextNumber(kind)` replaced the use cases' own `prefix + sequence` formatting.
