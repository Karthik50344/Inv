# Auditor export (Checkpoint D1: engine)

Code: `lib/features/auditor_exports/`, audit query side in `lib/features/audit/`. DI: `lib/app/di/register_exports.dart`.

## What it does
`GenerateAuditorExport` reads the chosen datasets for the chosen period, builds the file, saves it in the app's `exports` folder, **reads it back and verifies it**, records it in the history and notes it in the audit trail. If the saved file does not verify it is deleted and the user gets an error; no unverified export is kept.

## Period and datasets
Period: a financial year (April start by default; January gives a calendar year), a custom range, or all dates. Both ends are inclusive down to the last millisecond of the end day. Documents (invoices, returns, payments, expenses) are filtered by their own date; lines, allocations and reversals follow their document; stock movements by their time; audit events by their time. Master data, tax configuration and inventory balances are *as at export time* and the manifest says so (`periodApplied`).

Datasets: business profile, products, classifications, customers, suppliers, sales/purchase invoices (with lines), sales/purchase returns (with lines), payments (with allocations and reversals), expenses, inventory balances and valuation, stock movements, tax configuration, tax summaries (by component and treatment, plus per-line detail), HSN/SAC summaries, audit trail (chained events plus the legacy log), attachments, invoice PDFs. Summaries count **posted** documents only.

## Consistent snapshot, nothing mutated
All reads happen inside one database transaction (`ExportDataSource.inSnapshot`), so every file comes from the same state. Only SELECT runs against business tables. The one thing created is a connection-local temporary view, used to learn the column names of an empty result; it is never written to the database file. Epoch columns are shown as ISO text, amounts stay in minor units, and the manifest says so.

## Formats
- **ZIP**: `Inventrix_Audit_Export/` with `manifest.json`, `checksums/SHA256SUMS`, CSV files per dataset, business profile PDF, audit integrity report PDF, invoice PDFs, attachments (plus `attachments_index.csv`).
- **CSV**: one plain `.csv` when a single table is exported; otherwise a ZIP of CSV files with manifest and checksums.
- **XLSX**: one workbook, a `manifest` sheet and a sheet per table, written without a spreadsheet package (inline strings, never formulas). Excel's 1,048,576-row limit is respected with a visible `TRUNCATED` row.
- **PDF**: a report (facts, dataset counts, tax and HSN summaries, audit result). It does not contain every ledger row.

CSV cells that are text and start with `=`, `+`, `-`, `@`, tab or CR get a leading apostrophe so they can never run as formulas; numbers are untouched.

## Integrity, honestly
`SHA256SUMS` (sha256sum format) and the manifest each list a hash for every file; `ExportPackageVerifier` checks both and also catches added, removed or changed files and unsafe paths. This shows a package was **not changed after export**. It does **not** prove who made it: a checksum can be recomputed by anyone who edits the files. The manifest therefore carries `signature: null` and says "not signed". A signed manifest needs a properly managed key (platform secure storage plus an Ed25519 library); it is not built yet and the manifest never pretends otherwise.
The manifest also states the audit chain result and a checkpoint (last event sequence and hash). Keep that value outside the device; a later export can then show whether the chain was cut or rebuilt.

## History and sharing
`audit_export_history` keeps name, period, type, datasets, size, SHA-256, integrity status. `VerifyExportFile` re-checks a saved file. `ShareExportFile` uses the existing share / save dialogs; nothing is uploaded. `DeleteExportFile` removes the file but keeps the record. Created, shared and deleted exports are audit events (`data_export.*`), queued durably if the audit write fails.

## Not done yet (Checkpoint D2)
All screens: Audit & Export Center, audit log, event details with before/after, integrity verification, export wizard, history and export details, plus routing and navigation. Signed manifests. A tax-summary / HSN report screen.
