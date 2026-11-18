# Inventrix redesign: Phase 3, design system

Status: written, **not compiled or run** (no Flutter SDK where this was produced).
Run the commands at the end and send me the output before Phase 4.

## Where things live

The audit proposed keeping the existing locations instead of `lib/core/theme/`,
because `lib/core` is pure Dart here and `tool/check_imports.dart` treats it as
non-presentation.

| File | Role |
|---|---|
| `lib/app/theme/app_colors.dart` | `AppPalette` (full light and dark token sets) and `AppColors.seed` |
| `lib/app/theme/app_spacing.dart` | 4, 8, 12, 16, 20, 24, 32, 40, 48 plus layout constants |
| `lib/app/theme/app_radius.dart` | xs 6, sm 8, md 12, lg 16, xl 24, pill; role-named `BorderRadius` values |
| `lib/app/theme/app_shadows.dart` | Card and raised shadows. Light: soft. Dark: none on cards (border carries depth) |
| `lib/app/theme/app_typography.dart` | `TextTheme` scale and `AppTextExtension` (financial, table heading, caption, overline, code) |
| `lib/app/theme/app_theme_extensions.dart` | `AppColorsExtension` (success, warning, info, chart, extra surfaces) and `context.appColors` / `context.appText` |
| `lib/app/theme/app_theme.dart` | `AppTheme.light()` / `dark()` and every component theme |
| `lib/app/theme/app_dimensions.dart` | Compatibility shim over spacing and radius. Values unchanged, so no screen moves yet |
| `lib/features/settings/presentation/widgets/theme_mode_selector.dart` | System / Light / Dark segmented control |

Removed: `app_text_styles.dart` (replaced by `app_typography.dart`; nothing imported it).

## Decisions taken (defaults from the Phase 1 audit, since no answers came back)

- D6: brand moves from green to indigo. Light primary `#4F46E5`, dark `#8179F5`.
- D5: platform font. No font files bundled (offline-first, smaller app). Figures use tabular digits; codes use the platform monospace.
- D1/D2/D3/D4 do not affect Phase 3 (navigation, invented metrics, scanner and dashboard list are Phase 4/5 questions).
- No new `ThemeCubit`. Theme choice, persistence and live switching already existed (`SettingsCubit.setTheme`, Drift `themeMode`, `BlocBuilder` in `InventrixApp`). Phase 3 only replaces the dropdown with the three-way selector, key `settings_theme` kept.

## Palette

| Token | Light | Dark |
|---|---|---|
| background (page) | `#F4F6FB` | `#0B1220` |
| surface (card) | `#FFFFFF` | `#141C2E` |
| surfaceContainer | `#EDF0F8` | `#1A2438` |
| surfaceElevated (dialogs, menus) | `#FFFFFF` | `#222D45` |
| border | `#D9DFEC` | `#2B3652` |
| text / secondary | `#0F172A` / `#4B5870` | `#EDF1FA` / `#A9B4CB` |
| primary | `#4F46E5` | `#8179F5` |
| success / warning / error / info | `#047857 / #92400E / #B91C1C / #0369A1` | `#34D399 / #FBBF24 / #F87171 / #38BDF8` |

The Figma navy and indigo were estimated from screenshots (see the Phase 1 audit); the values above are the ones to adjust if you export exact variables.

Material surface mapping, so existing `Card`, `Dialog`, `NavigationBar` and `Scaffold` usages pick the right surface without edits: `surface` = page, `surfaceContainerLow` = card, `surfaceContainer` = grouped/nav, `surfaceContainerHigh` = dialog/menu.

Contrast: every text/background and semantic pair is at least 4.5:1 in both themes. I checked it with a script and `test/app/theme/app_palette_contrast_test.dart` asserts it. Disabled text and hairline borders are exempt by WCAG.

## Component themes

AppBar, Card, Divider, ListTile, InputDecoration, Filled / Elevated / Outlined / Text / Icon buttons, FAB, SegmentedButton, Chip, NavigationBar, NavigationRail, TabBar, Dialog, BottomSheet, SnackBar, PopupMenu, DropdownMenu, Switch, Checkbox, Radio, ProgressIndicator, Tooltip, DatePicker, TimePicker. Buttons have a 48 dp minimum height and a 64 dp minimum width (not full width, so a button in a `Row` does not blow up).

## Behavior changes you will see before Phase 4/5

The app turns indigo and gets rounded 12/16 px controls and cards everywhere, because the component themes apply to every existing screen. Layouts do not change. Dialogs are now 24 px rounded with a border. Bottom sheets get a drag handle by default. SnackBars float.

## Not done in Phase 3 (on purpose)

- Reusable widgets (`AppButton`, `AppCard`, ...): Phase 4.
- Restyling `AppShell`, `MorePage` and the existing shared widgets: Phase 4.
- Chart styling (`dashboard_charts.dart`, `trend_bar_chart.dart`) still uses `chartPalette()`; moving it to `AppColorsExtension.chart` is Phase 5 with the dashboard.
- Native splash to first-frame handover (`FlutterNativeSplash.preserve/remove`): needs the package under `dependencies` and the platform folders; Phase 4.

## Verify (run on your machine)

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test test/app/theme test/features/settings
flutter test
dart run tool/check_imports.dart
```

## Unverified API assumptions to watch in `flutter analyze`

Written for Flutter 3.35 or newer (Dart 3.9). If your SDK is older, these are the likely failures: `CardThemeData`, `DialogThemeData`, `TabBarThemeData` (older SDKs use `CardTheme`, `DialogTheme`, `TabBarTheme`), `Color.r/g/b` and `withValues` (3.27+), and the `ColorScheme.surfaceContainer*` and `surfaceDim/Bright` fields (3.22+). `very_good_analysis` rules could also flag line length or ordering. `dart format` fixes most of that.
