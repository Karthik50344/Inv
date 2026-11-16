# Backup & Restore (Phase 10)

> Warning shown on the Backup screen (and the Dashboard): *Your business data is stored locally on this device. Uninstalling the app or clearing its data may permanently delete your information. Export a backup to a safe external location regularly.*

## Archive format (`inventrix_backup_YYYYMMDD_HHmmss.zip`)

```text
backup.zip
├── manifest.json
├── database/inventory_management.sqlite
├── attachments/
│   ├── receipts/…          (expense receipts, <documents>/attachments)
│   └── product_images/…    (product photos, <documents>/product_images)
└── metadata/backup_info.json
```

`manifest.json`: `application` (`inventrix`), `formatVersion` (1), `appVersion`, `schemaVersion`, `createdAt` (UTC), and `files[]` with `path`, `sha256`, `sizeBytes` for **every** file except the manifest. Product photos are included because they are business data; the spec's single `attachments/` folder holds both folders as sub-folders.

## Creating a backup (`CreateBackup`)
1. Snapshot with `VACUUM INTO` (one read transaction: consistent while the app runs; the file is never copied raw).
2. `integrity_check` + `foreign_key_check` on the snapshot; a damaged database is **not** packaged.
3. Hash every file, write the ZIP to `*.part`, rename when complete (the archive never exists half-written).
4. Re-read the finished archive and verify every checksum; discard it if that fails.
5. Store it in `<documents>/backups/` and add a `backup_history` row (failures are recorded too).
6. The user then shares it (system share sheet) or saves it to a chosen location. Before export the archive's SHA-256 is compared with the recorded one.

Backups that exist only inside the app are lost with the app: **only an exported copy survives an uninstall.**

## Restoring (`PrepareRestore` → confirmation → `RestoreBackup`)
Validation touches nothing live:
- Entry names are checked **before** extraction: no `..`, absolute paths, drive letters, backslashes, control characters, links, duplicates (case-insensitive) or entries outside the layout; entry/size limits (50,000 entries, 4 GiB).
- Archive must match the manifest exactly (no extra, no missing file), sizes and SHA-256 are verified while extracting into a private staging folder (`<documents>/restore_staging/`), each target path is re-checked to stay inside it.
- `formatVersion`/`schemaVersion` newer than the app → refused. Older → accepted.
- `integrity_check`, `foreign_key_check`, and `user_version == manifest.schemaVersion`.
- The UI shows record counts and requires an explicit checkbox + button; the use case re-checks `confirmed`.

Applying (`RestoreBackup`), in this order:
1. Open the staged database with the app's own schema (runs migrations of older backups) and re-check it — still in staging.
2. Create and verify a **safety backup** of the current data. If this fails, nothing else happens.
3. Write `restore_journal.json` (state `swapping`) — the database is about to be replaced, so the intent cannot live in it.
4. `AppRuntime.shutDown()`: UI replaced by a neutral screen, service locator reset (closes the database).
5. `FileRestoreSwapper`: live files are **renamed** to `*.pre_restore` (never deleted), staged files renamed in. Failure → everything is put back.
6. `AppRuntime.start()`: dependencies re-registered, database opened (migrations), UI rebuilt. Failure → put back, start again.
7. Journal → `completed`, then the `*.pre_restore` files are deleted.

Crash safety: on every start, before the database opens, `RecoverInterruptedRestore` rolls back a journal still in `swapping`. After the database opens, `ReconcileRestoreJournal` writes the safety backup and the restore event into the (new) `backup_history`, removes leftovers and shows a one-time message. The history of the restored backup is whatever it was when that backup was taken, plus these rows.

## Known limits
- Archives are read file by file; the largest single file (the database) is held in memory during verification.
- "Save to device" passes the archive bytes to the file picker (needed on mobile), so it also loads the file into memory.
- Backups taken while another backup/restore is running are prevented only by the screen (one operation at a time), not by a global lock.
- Automatic/scheduled backups are not implemented (Phase 11 "backup preferences").
