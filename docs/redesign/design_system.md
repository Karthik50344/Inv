# Inventrix design system (redesign Phase 3)

Lives in `lib/app/theme/` (presentation-only, so it respects `docs/architecture/dependency_rules.md`). It stays there instead of `lib/core/theme/` because `lib/core` is pure Dart by convention here.

## Files

| File | Role |
|---|---|
| `app_colors.dart` | `AppPalette`: every color, one const palette per brightness (`AppPalette.light` / `.dark`). The **only** place hex values live. |
| `app_typography.dart` | Inter type scale: Material `TextTheme` plus `AppTextStyles` (display, page/section/card title, button, caption, table heading, 3 financial sizes with tabular figures). |
| `app_spacing.dart` | `AppSpacing.s4 … s48`, `pageGutter`, `page`/`card` insets, `gap*` / `hGap*` spacers. |
| `app_radius.dart` | `AppRadius`: small 8, control 12, card 16, nav 16, dialog 20, sheet 24, pill. |
| `app_shadows.dart` | `AppShadows.card/floating/overlay(brightness)`. Dark cards use borders, not shadows. |
| `app_theme_extensions.dart` | `AppColorTokens` (success / warning / danger / info / brand / neutral as `AppStatusColor`, chart colors, borders, shadows) and `context.appColors`, `context.appText`. |
| `app_component_themes.dart` | Component themes (app bar, card, inputs, buttons, chips, nav bar and rail, dialog, bottom sheet, snackbar, list tile, switch, checkbox, radio, segmented button, progress, tooltip, menus, date picker, selection). |
| `app_theme.dart` | `AppTheme.light()` / `.dark()`; also `AppTheme.colorScheme(palette)`. Public API is unchanged, so `app.dart`, `inventrix_host.dart` and `startup_failure_app.dart` need no edits. |
| `app_dimensions.dart` | Kept as is, for the 38 existing files that use it. New code uses `AppSpacing` / `AppRadius`; the old file is retired in Phase 5. |

Removed: `app_text_styles.dart` (replaced by `app_typography.dart`; nothing else imported it).

## Rules for feature code

1. No `Color(0x…)` or `Colors.x` in feature widgets. Use `Theme.of(context).colorScheme`, or `context.appColors` for success / warning / danger / info / neutral / chart / borders.
2. Status chips and badges take an `AppStatusColor` (`solid`, `onSolid`, `container`, `onContainer`), never raw colors.
3. Amounts use `context.appText.financial*` (tabular figures) and the existing money formatter. The symbol is never hardcoded.
4. Spacing and radii come from `AppSpacing` and `AppRadius`.

## Colors

| | Light | Dark |
|---|---|---|
| Page | `#F2F4F9` (tinted) | `#0B1220` (navy) |
| Card | `#FFFFFF` | `#121A2D` |
| Elevated (dialog, sheet, menu) | `#FFFFFF` | `#1A2540` |
| Primary | `#4F46E5` | `#5B50EA` |
| Brand text / focus ring | `#4338CA` | `#A8A2FF` |
| Success / warning / error / info | `#0B7A55` / `#9A5206` / `#C9302C` / `#1D5FD1` | `#34D399` / `#FBBF24` / `#F87171` / `#60A5FA` |
| Control border | `#7D87A2` | `#6A78A6` |

Dark primary is slightly different from light so white text on it passes 4.5:1. Dark brand *text* uses a lighter tint for the same reason. Values were estimated from Figma screenshots, since exact tokens could not be read.

Verified (Python mirror of the palette, and `test/app/theme/app_theme_test.dart`): primary text 7:1 or better and secondary text 4.5:1 or better on every surface; colored text 4.5:1 on page, card and container; every `on*` color 4.5:1 on its fill; control borders 3:1; chart colors 3:1 on cards.

## Typography

Inter (OFL, Latin subset, about 730 KB for four weights), bundled in `assets/fonts` and declared in `pubspec.yaml`. Scripts outside the subset (for example Tamil in a business name) fall back to the system font.

Page title 22/700 · section title 16/600 · card title 15/600 · body 16 / 14 / 12 · label 14 / 12 / 11 · button 14/600 · financial 28 / 18 / 14.

## Theme switching

Already existed and is unchanged: `ThemePreference` → `SettingsCubit.setTheme` → Drift → `InventrixApp` `BlocBuilder` → `themeMode`. Phase 3 only replaces the settings dropdown with `ThemeModeSelector` (System / Light / Dark segmented control, key `settings_theme` kept). Switching animates over Flutter's default 200 ms with no restart.

## Not yet verified (no Flutter SDK was available)

- Nothing here was compiled or tested.
- Flutter has been renaming theme classes. If the analyzer rejects `InputDecorationTheme` in `AppComponentThemes.inputDecoration`, change it to `InputDecorationThemeData` (return type and constructor, same fields). `CardThemeData`, `DialogThemeData` and `FadeForwardsPageTransitionsBuilder` need Flutter 3.29 or newer.
- `FontFeature` is used through `material.dart`; if the analyzer says it is undefined, add `import 'dart:ui' show FontFeature;`.
- Visual check on a device of: bottom sheets (a drag handle is now on every modal sheet), chip selection, text-field focus ring, switch and checkbox states.
- Existing widget tests that look for old widgets or exact colors may need updating; I found none referencing the theme dropdown.
