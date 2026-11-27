# Database and backup encryption

Status: Issue 1 of the production-hardening series. Implemented and tested as
described under "Verification" below.

## What is protected

| Asset | Protection |
|---|---|
| Live database `inventory_management.sqlite` | SQLCipher 4 (AES-256-CBC + HMAC-SHA512 per page), raw 256-bit key. The whole file is encrypted, including schema, indexes, free pages. |
| Backups (`*.ivxbak`) | AES-256-GCM authenticated container ("IVXBAK" v1). Contains the ZIP payload. The database inside stays SQLCipher-encrypted. |
| Database key | Android Keystore / iOS Keychain through `flutter_secure_storage`. Never in files, `SharedPreferences` or the database. |

Attachments (product photos, receipts) under `documents/` are **not**
encrypted at rest by this change; they are encrypted inside backups.

## Engine

`pubspec.yaml` bundles SQLCipher through the `sqlite3` build hook:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlcipher
```

A plain SQLite build **silently ignores `PRAGMA key`** and would create an
unencrypted file (verified). Therefore the app:

1. refuses to start unless `PRAGMA cipher_version` returns a SQLCipher version,
2. checks after opening that the file on disk does not start with
   `SQLite format 3` (`assertEncryptedOnDisk`).

Do not add `sqlite3_flutter_libs` / `sqlcipher_flutter_libs`.

## Key management (`lib/core/security`)

* 32 random bytes from `Random.secure()`, stored as 64 hex characters.
* Android: `resetOnError: false`. The plugin default (`true`) would erase all
  stored secrets after a Keystore error, destroying the key.
* iOS: `first_unlock_this_device` (not synced to iCloud, not restored to another
  device).
* A **new key is generated only when nothing depends on an older one**: no
  database exists, or a plaintext database is being migrated.
* Encrypted database present but key missing → `keyMissing`; key present but
  wrong → `unlockFailed`; stored key damaged → `keyInvalid`; storage not
  readable → `keyStorageUnavailable`. All show a specific message on the start-up
  failure screen. **Nothing is deleted, reset or regenerated.**

## Migration of existing installs (`EncryptedDatabaseOpener`)

Plaintext database found at start-up:

1. Create/read the key.
2. `ATTACH` a new file with the key, `sqlcipher_export`, copy `user_version` and
   `application_id` (Drift's schema version lives in `user_version`; the export
   does not copy it), compare every table's row count, `integrity_check`.
3. Open the new file with the key.
4. Rename plaintext → `.plaintext-old`, new → live, open the live file with the key.
5. Overwrite the old plaintext with zeros and delete it (and `-wal`/`-shm`).

If any step fails the plaintext original is put back untouched. A crash between
steps is recognised from the files present at the next start
(`.encrypting`, `.plaintext-old`, `.unverified`) and finished or undone; the
plaintext original is deleted only after the encrypted file has been proven.
Tested for each of these states.

## Backup container (`BackupEnvelope`)

```
"IVXBAK" | version u16 | headerLength u32 | header (JSON) | chunk...
```

* Random 256-bit data key (DEK) per backup. Payload in 64 KiB chunks,
  AES-256-GCM, nonce = `prefix(7) | counter(4) | last-flag(1)`, additional
  authenticated data = the whole header. Detects bit flips, truncation (also at
  a chunk boundary), appended data, reordered chunks, header edits.
* **Key slots** wrap the DEK:
  * `device`: HKDF-SHA256 of this installation's backup key (secure storage).
  * `passphrase` (optional): Argon2id (19 MiB, 2 passes, 1 lane; parameters stored in
    the file and bounded when read).
* The database key is wrapped with the DEK so another device can open the
  database inside, then **re-key it to its own key** (`PRAGMA rekey`) before it
  replaces anything.
* Header fields are bounded (header ≤ 16 KiB, chunk ≤ 1 MiB, Argon2 ≤ 256 MiB) so
  a hostile file cannot exhaust memory.

The only plaintext intermediate is the ZIP in a private scratch folder; it is
overwritten with zeros and deleted in a `finally` block. The database snapshot
(`VACUUM INTO`) is itself SQLCipher-encrypted (verified).

## Restore

`PrepareRestore` → decrypt and authenticate **before** anything else → verify
ZIP manifest checksums → open the staged database with its key → schema and
integrity checks → `RestoreBackup` re-keys the staged database to this
device's key and re-opens it with that key → safety backup → atomic swap with
the existing journal/rollback. A failure at any point before the swap leaves
the live data untouched. After a restore the live database opens with the key in
secure storage, so keys stay consistent.

Backups made on another device or after a reinstall need the recovery
passphrase; the app asks for it. A backup made **without** a passphrase can only
be opened by the installation that made it (the UI says so before creating it).

### Legacy (pre-encryption) ZIP backups

Decision for review: they can still be **restored** (`BackupFormat.allowLegacyPlaintextRestore = true`) so existing user backups are not orphaned; they are never created. They are not authenticated (only their SHA-256 manifest), and
restoring one re-encrypts the data. Set the constant to `false` to refuse them.

## Security boundary and limits (what this does not do)

* Protects data **at rest** against someone who obtains the database file or a
  backup file (lost device image, file copied off, shared backup). It does not
  protect a running, unlocked app, or a device where an attacker can run code as
  the app or read its memory.
* On a rooted/jailbroken device, or with a debugger, keys can be extracted from
  the running process. Keystore/Keychain make the key hard to copy off the device
  but cannot stop the app itself from using it. SQLCipher keeps key material in
  process memory while the database is open (its memory-locking feature reported
  disabled in the bundled build).
* Wiping deletes by overwriting, but flash storage and journaling filesystems may
  keep old blocks; encryption-at-rest of the device (Android FBE / iOS data
  protection) is the real mitigation for the old plaintext.
* A backup without a recovery passphrase cannot be restored after reinstall.
  A forgotten passphrase cannot be recovered. A weak passphrase can be guessed
  offline; Argon2id only slows this down (minimum length 10).
* Attachments outside backups are not encrypted.
* Android Auto Backup / device transfer can copy the database file but not the
  Keystore key; see "Platform setup".

## Platform setup (the zip contains no `android/` or `ios/` folders)

* `flutter_secure_storage` 11 needs Android `minSdk` ≥ 24.
* In `AndroidManifest.xml` exclude the database and key storage from cloud
  backup/device transfer so a restored phone never has a database without its key:
  set `android:allowBackup="false"`, or provide
  `android:dataExtractionRules`/`android:fullBackupContent` rules that exclude
  the app's `files/` database and the `FlutterSecureStorage` shared preferences.
* Needs Flutter ≥ 3.38 / Dart ≥ 3.10 (native-asset build hooks). First build
  downloads the prebuilt SQLCipher binaries from the `sqlite3.dart` GitHub release
  (hashes are pinned inside the package).

## Verification

See the test list in the Issue 1 report. Real-library tests:
`test/core/database/sqlcipher_integration_test.dart`,
`test/core/database/encrypted_app_database_test.dart`,
`test/features/backup/real_encrypted_backup_restore_test.dart`.
