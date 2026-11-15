# Inventrix

Offline-first Inventory Management & Billing for Android and iOS, built with
Flutter. All business data is stored locally in SQLite (Drift); there is no
login.

| | |
|---|---|
| App name | Inventrix |
| Dart package | `inventrix` |
| Android application ID / iOS bundle ID | `com.rk.inventrix` |
| Architecture | Feature-first Clean Architecture |
| State management | BLoC/Cubit (introduced from Phase 2) |
| Navigation | GoRouter (bottom bar on phones, rail on wide screens) |
| Database | Drift + SQLite (`inventory_management.sqlite`) |
| DI | GetIt |

> **Your business data is stored locally on this device.** Uninstalling the
> app or clearing its data may permanently delete your information. Export a
> backup to a safe external location regularly.

## Status

Phase 3 (Inventory) written on top of Phase 2 (Master data) and Phase 1 (Foundation). See
`docs/development/progress.md` for exactly what has and has not been verified.

## Getting started

```bash
bash setup.sh            # first time: creates project, adds deps, runs checks (Phases 1-2)
# afterwards
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
dart run tool/check_imports.dart   # architecture dependency rules
flutter run
```

Tests that use `NativeDatabase` run on the host and need the SQLite library
installed on the development machine (preinstalled on macOS; on Linux
`sudo apt install libsqlite3-dev`).

## Project layout

```text
lib/
  app/        bootstrap, app widget, router, shell, theme, DI
  core/       errors (Failure), result (Result<T>), database (Drift), utils,
              services (TransactionRunner), logging, constants
  shared/     value objects (Money, Quantity), reusable widgets
  features/   one folder per feature (dashboard placeholder in Phase 1)
docs/         architecture, database, workflows, development notes
tool/         check_imports.dart (dependency-rule checker)
```

## Foundations delivered in Phase 1

- `Money` (integer minor units, explicit half-away-from-zero rounding,
  currency-safe arithmetic, tax/discount helpers) and `Quantity` (integer
  milli-units). No `double` is used for money or stock.
- `Result<T>` and a sealed `Failure` hierarchy; database errors are mapped to
  user-safe failures.
- Drift database with foreign keys enabled, CHECK constraints, an
  append-only stock ledger and a transaction abstraction.
- GetIt wiring, GoRouter navigation, light/dark Material 3 themes, base
  widgets.

See `docs/` for the full design.
