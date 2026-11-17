# Inventrix branding (redesign Phase 2)

## The mark

Three columns of one, two and three blocks: stock stacking up and a bar chart in one shape. The top block of the tallest column is the accent; it marks the "number that matters". It has no text, so it survives at launcher size, and it avoids cart and box clichés.

| Token | Hex | Use |
|---|---|---|
| Indigo | `#4F46E5` | Brand color on light backgrounds, icon tile |
| Indigo (on dark) | `#8179F5` | Same hue lifted for dark backgrounds |
| Mint | `#10B981` | Accent block on light backgrounds |
| Mint (on dark / tile) | `#34D399` | Accent block on dark backgrounds and the icon tile |
| Navy | `#0B1220` | Dark background, light-background wordmark |
| Splash light | `#F4F6FB` | Native splash background (light) |

Wordmark: **INVENTRIX** in Inter ExtraBold, +7.5 % tracking, converted to outlines (no font is needed to view the SVGs). The icon colors are the Phase 3 theme seed, so the app and its icon share one palette. The Figma indigo and navy were estimated from screenshots (exact values were not readable); confirm or replace them in `tool/branding/generate_branding.py` and re-run it.

## Files (`assets/branding/`)

| File | Purpose |
|---|---|
| `inventrix_logo.png` | Primary logo (identical to `_light`) |
| `inventrix_logo_light.png` / `_dark.png` | Horizontal lockup for light / dark backgrounds |
| `inventrix_logo_mono.png` / `_mono_white.png` | One-color lockups (navy / white) |
| `inventrix_symbol.png` / `_dark.png` | Icon-only mark on transparent, light / dark |
| `inventrix_icon.png` | 1024 px full-bleed launcher tile (iOS, legacy Android). No alpha. |
| `inventrix_icon_foreground.png` | Android adaptive foreground (mark inside the safe zone) |
| `inventrix_icon_monochrome.png` | Android 13 themed icon |
| `inventrix_splash.png` / `_dark.png` | Native splash mark (iOS and Android 11 and below) |
| `inventrix_splash_android12.png` / `_dark.png` | Android 12+ splash icon (960 px, mark inside the 640 px circle) |
| `inventrix_wordmark.png` / `_dark.png` | Splash branding image (bottom) |
| `src/*.svg` | Vector sources: symbol, icon tile, all lockups |

Only the four in-app logos (`logo_light/dark`, `symbol`, `symbol_dark`) are declared in `pubspec.yaml` `assets:`. The rest are generator input and are not bundled.

## Generate the native resources

Needs the `android/` and `ios/` folders present (they were not in the uploaded zip).

```bash
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Then uninstall the old app before running, since launchers and the Android 12 splash cache the previous icon.

Regenerating the artwork itself (only if the mark or colors change): `python3 tool/branding/generate_branding.py` (needs Pillow, fonttools and Inter ExtraBold; set `INVENTRIX_FONT` to its path).

## Not done / to check on device

- None of the generator commands were run (no Flutter SDK or platform folders where this was produced).
- Check the icon on a real launcher with round, squircle and themed-icon modes. A contact sheet of simulated masks looked right, but that is not a device.
- Check that the splash hands over to the first Flutter frame without a flash. The app loads settings before its first frame, so the splash may show briefly longer. If there is a visible gap, add `FlutterNativeSplash.preserve` / `remove` in the bootstrap (needs the package moved from `dev_dependencies` to `dependencies`); that is a code change and is left for Phase 3.
- `adaptive_icon_monochrome` needs `flutter_launcher_icons` 0.13 or newer, so `^0.14.1` is fine.
