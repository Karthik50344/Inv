# Migrations

- Drift `schemaVersion` starts at **1** (Phase 1) and increments per schema change; each phase that adds tables adds a migration step.
- `MigrationStrategy`: `onCreate` creates all; `onUpgrade` runs stepwise `from → to` steps (use Drift's `stepByStep`); `beforeOpen` enables `PRAGMA foreign_keys = ON` and runs `PRAGMA foreign_key_check` in debug builds.
- After each schema change run `dart run drift_dev schema dump` to store `drift_schemas/drift_schema_vN.json`, and `drift_dev schema generate` for test helpers.
- Every migration has a `SchemaVerifier` test (v(n-1) → v(n)) that also seeds data and asserts it survives.
- Never drop/alter columns containing financial data without a copy-and-verify migration.
- Never silently reset the DB; a failed migration aborts startup with a recovery screen that offers backup export.
- Pre-migration safeguard: before upgrading a non-empty DB, take an automatic `VACUUM INTO` copy in the app's private dir (kept for the last 2 upgrades).


## Version history
| Version | Phase | Change |
|---|---|---|
| 1 | 1 | Initial schema: business_profiles, app_settings, categories, units, tax_rates, products, inventory_balances, stock_movements (+ indexes/triggers in `schema_extras.dart`) |
| 2 | 2 | Adds customers, suppliers (+ name indexes via `kSchemaExtraStatementsV2`). Additive only. |

`onUpgrade(from < 2)` creates the two tables and runs the V2 extras; `onCreate` runs both extras lists. `test/core/database/migration_test.dart` **simulates** a v1 file (drops the v2 tables, rewinds `user_version`) and checks existing rows survive. Replace it with `SchemaVerifier` tests once `drift_dev schema dump` snapshots exist (run the dump at v2 now, before v3).

| 3 | 3 | Adds `audit_logs` (+ append-only triggers via `kSchemaExtraStatementsV3`). Additive only. |

`test/core/database/migration_test.dart` now simulates both 1 -> current and 2 -> 3 upgrades. Run `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/` and replace the simulations with `SchemaVerifier` tests as soon as Drift code generation works on your machine.

| 4 | 4 | Adds `document_sequences`, `purchase_invoices`, `purchase_invoice_items` (+ indexes and immutability triggers via `kSchemaExtraStatementsV4`, plus the missing `idx_audit_logs_entity`). Additive only. |

`onUpgrade(from < 4)` creates the three tables and runs the V4 extras (all `IF NOT EXISTS`). The migration simulations drop the v4 tables (items, invoices, sequences, in that order) before rewinding `user_version`; `test/core/database/migration_test.dart` also has a 3 -> 4 test, and `purchase_schema_test.dart` exercises every constraint and trigger. **Run `dart run build_runner build --delete-conflicting-outputs` after pulling this phase: `app_database.g.dart` must be regenerated for the new tables.**

| 5 | 5 | Adds `sales_invoices`, `sales_invoice_items` (+ indexes and immutability triggers via `kSchemaExtraStatementsV5`). Additive only. |

`onUpgrade(from < 5)` creates both tables and runs the V5 extras (all `IF NOT EXISTS`). The older migration simulations now also drop the sales tables before rewinding `user_version`; `migration_test.dart` has a 4 -> 5 test and `sales_schema_test.dart` exercises the constraints and triggers. **`app_database.g.dart` must be regenerated** (`dart run build_runner build --delete-conflicting-outputs`).
| 6 | 6 | Payments: `payment_methods` (seeded: Cash, Bank transfer, Card, Other), `payments`, `payment_allocations`, `payment_reversals`; unique number / idempotency key / one reversal per payment; append-only and over-allocation triggers (`kSchemaExtraStatementsV6`) |
| 7 | 7 | Returns: `sales_returns`, `sales_return_items`, `purchase_returns`, `purchase_return_items` (+ append-only, over-return and void-after-return triggers via `kSchemaExtraStatementsV7`). Additive only. |

`onUpgrade(from < 7)` creates the four tables (`createTable` is `IF NOT EXISTS`) and runs the V7 extras. The older migration simulations drop the return tables first; `migration_test.dart` has a 6 -> 7 test and `return_schema_test.dart` exercises the constraints. **`app_database.g.dart` must be regenerated.**

## Schema version 8 (Phase 8)
Adds `expense_categories`, `expenses` and `attachments` (`onUpgrade`: `from < 8` creates the three tables, runs `kSchemaExtraStatementsV8`, then seeds the default expense categories with `INSERT OR IGNORE`; `onCreate` does the same). No existing table or row is changed.

Extra SQL (idempotent): partial unique indexes on active category names and on expense numbers; indexes on expense date, (category, date) and status; `trg_expenses_protect` (posted/voided/cancelled expenses are immutable, except posted → voided with every identifying and financial column unchanged), `trg_expenses_no_delete`, `trg_attachments_no_update`, `trg_attachments_insert_open` (the owner expense must exist and be draft/posted), `trg_attachments_delete_draft_only`.

Tested by `migration_test.dart` (7 → 8 keeps data, seeds 8 categories, creates the guards; older upgrade tests also drop the new tables when simulating an old database) and `expense_schema_test.dart`.

