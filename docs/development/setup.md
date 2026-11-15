# Development Setup

```bash
bash inventrix_phase1/setup.sh      # creates `inventrix/`, applies overlay, installs deps, runs checks
```

What the script does, in order: `flutter create --org com.rk --project-name inventrix --platforms android,ios`
(gives Android `applicationId` and iOS bundle ID `com.rk.inventrix`), copies the overlay, sets the Android label to
"Inventrix", verifies both IDs, adds Phase 1 dependencies with `flutter pub add`, runs `build_runner`, `dart format`,
`flutter analyze`, `flutter test`, and `tool/check_imports.dart`.

Manual checks after the first run:
- iOS display name: `CFBundleDisplayName` in `ios/Runner/Info.plist` should read `Inventrix`.
- Record `flutter --version` and `dart --version` here:  _TBD (not yet run)_.
- Commit `pubspec.lock`.

Phase 1 dependencies: go_router, get_it, drift, drift_flutter, intl, logging, sqlite3; dev: build_runner,
drift_dev, very_good_analysis. Everything else in the proposed list is added in the phase that needs it.

After the schema changes in any later phase: `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`.
