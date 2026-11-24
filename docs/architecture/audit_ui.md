# Audit & export screens (Checkpoint D2)

Entry: More > System > **Audit & export** (`/more/audit`). Code: `lib/features/audit/presentation/`, `lib/features/auditor_exports/presentation/`. Routes are children of `/more/audit`: `log`, `event/:id`, `integrity`, `export`, `exports`, `exports/:id`.

| Screen | What it shows | State |
|---|---|---|
| Audit & export (dashboard) | Recorded events, cancelled documents, reversed payments, tax setting changes, stock events, exports created (all counted from the real events), what is recorded by type, recent events, recent exports, shortcuts | `AuditCenterCubit` |
| Audit log | Search, date range, event type, record type, person, document number; paging; "export the audit trail" with the current dates pre-filled | `AuditLogCubit` |
| Event details | Who, when, record, reason, before/after comparison, more details, this event's integrity, other events of the same action | `AuditEventCubit` |
| Check integrity | Walks the whole chain, plain-language result, create a checkpoint to keep outside the device, compare a saved checkpoint | `AuditIntegrityCubit` |
| Create export | Four steps: period, content, file type, review; result with share/save | `ExportWizardCubit` |
| Exports | Name, date, period, type, size, item count, integrity badge | `ExportListCubit` |
| Export details | Facts, contents, file fingerprint, share, save, check again, remove file (record stays) | `ExportListCubit(only: id)` |

## Wording rules
Screens never show codes such as `sales_invoice.voided`: `AuditLabels` turns them into "Sales invoice voided". A person's name is always labelled "local operator, not verified" (there is no sign-in), and the event page repeats that. Amounts in before/after views are the stored values (minor units for money fields), shown as recorded.

## Design notes
- All screens use the shared `App*` widgets and theme tokens, scroll on small screens, are width-limited on large ones, and are tested in light and dark themes.
- The wizard never changes business data; the export result is verified after saving (see `auditor_export.md`). While an export is being created Back is disabled and the page cannot be popped.
- Dates in filters are whole days; the end day is inclusive.

## Not built
Setting the local operator name from the UI (the setting key `audit_operator_name` exists), tax-summary and HSN/SAC report screens (the data is in the export), signed manifests.
