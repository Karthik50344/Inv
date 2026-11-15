#!/usr/bin/env bash
# Creates the Flutter project (if needed), applies the Phase 1 overlay, adds
# the Phase 1 dependencies, generates code, and runs the verification
# commands. Run from the directory where `inventrix/` should live:
#
#   bash inventrix_phase1/setup.sh [target-dir]
#
# Requires: Flutter SDK on PATH, network access to pub.dev.
set -euo pipefail

OVERLAY="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$PWD/inventrix}"

if [ ! -d "$TARGET" ]; then
  flutter create --org com.rk --project-name inventrix \
    --platforms android,ios "$TARGET"
fi

rm -f "$TARGET/test/widget_test.dart"
for dir in lib test tool docs; do
  mkdir -p "$TARGET/$dir"
  cp -R "$OVERLAY/$dir/." "$TARGET/$dir/"
done
cp "$OVERLAY/analysis_options.yaml" "$OVERLAY/README.md" "$TARGET/"

cd "$TARGET"

# Branding: display name "Inventrix" on both platforms.
sed -i.bak 's/android:label="[^"]*"/android:label="Inventrix"/' \
  android/app/src/main/AndroidManifest.xml && rm -f android/app/src/main/AndroidManifest.xml.bak

# Identity check: fail early if the IDs are not com.rk.inventrix.
grep -rq 'com.rk.inventrix' android/app/build.gradle* \
  || { echo "Android applicationId is not com.rk.inventrix"; exit 1; }
grep -q 'com.rk.inventrix' ios/Runner.xcodeproj/project.pbxproj \
  || { echo "iOS bundle id is not com.rk.inventrix"; exit 1; }

# Dependencies for Phases 1-2 (versions resolved by pub, never hand-written).
flutter pub add go_router get_it drift drift_flutter intl logging sqlite3 \
  flutter_bloc bloc equatable uuid path path_provider file_picker
flutter pub add --dev build_runner drift_dev very_good_analysis bloc_test
# NOTE: check drift_flutter's README for your Flutter/sqlite3 versions. If it
# still requires it, also run: flutter pub add sqlite3_flutter_libs

dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
dart run tool/check_imports.dart
