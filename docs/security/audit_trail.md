# Audit trail

Code: `lib/features/audit/`. Tables: `audit_events`, `audit_outbox` (schema v12). The older `audit_logs` table is kept read-only for history.

## What an event holds
`id, eventType, entityType, entityId, action, actor (type, id, display name), occurredAtUtc, reason, source, correlationId, previousValues, newValues, metadata, previousEventHash, eventHash, schemaVersion`. Values are readable JSON. Never put passwords, tokens or other secrets in a draft; the business profile audit records only the *names* of changed fields, not contact details.

## Who did it
Inventrix has no sign-in. The recorded actor is the **local operator** (a name typed in the setting `audit_operator_name`) or **this device**. Neither is verified; `AuditActor.isVerified` is true only for the reserved `authenticated_user` type, which nothing writes today. Migrations and repairs can record the `system` actor.

## Append-only
Database triggers refuse `UPDATE` and `DELETE` on `audit_events`. The app offers no edit or delete. A correction is a new event.

## Hash chain
`eventHash = SHA-256(canonical JSON of every field + previousEventHash)`. Canonical JSON has sorted keys, no whitespace, ISO UTC dates, and rejects unsupported values. The first event of the chain is `audit.chain_started` (previous hash = 64 zeros); it records how many legacy `audit_logs` rows exist. **Those older rows are not covered by the chain**: hashing them now would suggest they were tamper-evident all along.

`VerifyAuditChain` walks the events in order and reports the first problem: edited event (`hashMismatch`), removed/inserted event (`brokenLink`), wrong order (`outOfOrder`).

## What the chain does not protect against
The chain lives in the same SQLite file as the data. Someone with direct access to the file can drop the triggers, change events and recompute every later hash, and the chain will still verify. Deleting the *newest* events is also invisible to the chain alone. Mitigations provided:
- `CreateAuditCheckpoint` returns the last event's sequence and hash. Keep it somewhere the database cannot reach (printed, e-mailed, or inside an export manifest). `VerifyAuditChain(checkpoint:)` then reports `checkpointMissing` if the chain was cut or rebuilt after that point.
- The auditor export (Checkpoint D) will include a checkpoint and, optionally, a signed manifest. A checksum alone proves integrity, not authenticity.

## Atomicity and failures
- Existing use cases call `AuditLogRepository.record` inside their transaction and return its failure, so a business change and its audit event commit together or not at all (**fail-closed**). The repository now writes `audit_events`; the ~28 call sites did not need to change.
- Every database transaction opens a correlation scope (`AuditCorrelation`, set by `DriftTransactionRunner`), so all events of one operation share a `correlationId`.
- Work that cannot share a transaction uses `AuditRecorder.recordOrQueue`: if the audit write fails, the event is parked in `audit_outbox` with its original actor and time, and flushed (in order) before the next audit write and by `flushOutbox`. Only if the outbox write also fails is the user told.

## Events recorded now
Everything already audited (sales, purchases, returns, payments, expenses, stock, settings, tax rates; voids and reversals now carry `reason` and status before/after; stock adjustments carry reason and quantity; currency, tax-rate and preference changes carry before/after), plus products (created, updated with only the changed fields, archived, restored; tax-related changes flagged) and product classifications (added, updated, removed, primary changed).

## Not yet audited
Categories, units, customers, suppliers; backup create/restore, import and data export events (the outbox path is ready for them); tax regime/profile/rule/component edits (there are no editing screens yet). Planned for later steps.
