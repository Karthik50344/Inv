# Backup & Restore

## Backup
1. Block concurrent writes briefly via a repository-level mutex.
2. `VACUUM INTO` temp snapshot (consistent).
3. Copy attachments, write `metadata/`, compute SHA-256 for each file, write `manifest.json` (app version, schema version, created_at, file list + checksums).
4. ZIP → `backup.zip`; store SHA-256 of the archive in `backup_history`.
5. Offer export via `share_plus`/`file_picker` to an external location.

```text
backup.zip
├── manifest.json
├── database/inventory_management.sqlite
├── attachments/
└── metadata/
```

## Restore
1. User picks file; show confirmation describing what will be replaced.
2. Extract into a temp dir, rejecting entries with `..`, absolute paths, or symlinks (ZIP path traversal).
3. Verify manifest, checksums, `PRAGMA integrity_check`, `PRAGMA foreign_key_check`, and that backup schema version ≤ app schema version (older backups are migrated in the temp copy).
4. Take a safety copy of the current DB.
5. Close Drift connection, atomically swap files, reopen, re-initialize DI.
6. On any failure, keep/restore the existing DB and show a `RestoreFailure`.

The prominent local-storage warning text from the spec is shown on the Dashboard banner, Backup screen, and first launch.
