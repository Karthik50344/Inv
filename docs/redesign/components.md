# Shared components (redesign Phase 4)

All in `lib/shared/presentation/widgets/`; `app_widgets.dart` re-exports everything. Every component reads colors from the theme, so it follows light, dark and system mode with no extra code.

| Brief name | Class / function | Notes |
|---|---|---|
| AppButton | `AppButton` | Variants: primary, secondary, outlined, text, destructive. Sizes 48 / 40. `loading` shows a spinner and ignores taps. `expand` fills the width. |
| AppIconButton | `AppIconButton` | `tooltip` is required (it is the accessibility label). Variants: standard, filled, tonal, outlined. Optional badge dot. |
| AppTextField | `AppTextField` | Wraps `TextFormField`; keyboard actions are set (next / newline). Supports prefix, suffix, validator, formatters. |
| AppDropdown | `AppDropdown<T>` + `AppDropdownItem` | Rebuilds when `value` changes, so it works with BLoC state. |
| AppSearchField | `AppSearchField` | Clear button, trailing slot (for a filter button). `SearchField` is kept as a thin wrapper for existing screens. |
| AppCard | `AppCard` | Border, faint light-mode shadow, optional `onTap`, `selected`, alert `tone`. |
| AppStatCard | `AppStatCard` | KPI tile. Takes an already-formatted value, so it never formats money itself. Scales long values down instead of overflowing. |
| AppSectionHeader | `AppSectionHeader` | Title, subtitle, "View all" action. |
| AppAppBar | `AppAppBar` | Flat, left-aligned, optional subtitle and bottom. |
| AppBottomNavigation | `AppBottomNavigation`, `AppNavigationRail`, `AppNavItem` | Wrap the real `NavigationBar` / `NavigationRail`, so the existing router tests still find them. The rail shows the Inventrix mark. |
| AppDrawer | not built | The app navigates with a bottom bar (phones) and a rail (wide). A drawer would be a third, redundant pattern. |
| AppChip | `AppChip` | Selectable filter chip with optional count. |
| AppBadge | `AppBadge` | Status pill; soft or solid. |
| AppEmptyState / AppErrorState / AppLoadingState | `EmptyState`, `ErrorState`, `LoadingIndicator` (aliases `AppEmptyState` etc.) | Kept under their old names (used by about 110 call sites); APIs unchanged. Now scroll-safe in short boxes. |
| AppConfirmationDialog | `showConfirmationDialog` + `AppConfirmationDialog` | Same function signature. Icon, centered text, outlined cancel, destructive variant. |
| AppBottomSheet | `showAppBottomSheet`, `AppBottomSheet` | Keyboard-aware, scrolls when tall, 640 px max width. |
| AppDatePicker | `showAppDatePicker`, `showAppDateRangePicker`, `AppDatePickerField` | Field shows the date in the user's chosen date style. |
| AppFilterButton | `AppFilterButton` | Shows how many filters are active. |
| AppDataTable | `AppDataTable`, `AppDataColumn`, `AppDataRow` | Fills the width, or scrolls sideways when columns do not fit. |
| AppCurrencyText | `AppCurrencyText` | Takes a `Money`; uses `MoneyFormatter` (currency and number style from settings) and tabular figures. |
| (extra) | `AppRefreshIndicator`, `AppTone`, `showAppMessage(type:)` | Pull-to-refresh; the status color vocabulary; success / error snackbars. |

## Also restyled

- **App shell:** uses `AppBottomNavigation` / `AppNavigationRail` (hairline borders, brand indicator).
- **More screen:** three groups (Operations, Insights, System) of icon-tile rows with a one-line description. `MoreDestination` gained `group` and `subtitle`. Group names avoid every destination title, because the router test requires each title to appear once.
- **404 and coming-soon pages:** `AppAppBar`, `AppButton`.
- **`DocumentStatusChip`:** now an `AppBadge`; same key (`status_<name>`) and label. Tones: posted green, approved/authorized brand, pending approval amber, created blue, voided/cancelled red, draft neutral.
- **`LocalDataWarningBanner`:** warning tone instead of error red (it is a reminder, not a failure).

## Rules

- Screens take status color from `AppTone`, never raw colors.
- Wrap list screens in `AppRefreshIndicator` and give the list `AppRefreshIndicator.physics`.
- Show money through `AppCurrencyText`, or format with `MoneyFormatter` when a plain `String` is needed (`AppStatCard.value`).

## Not done in this phase (belongs to Phase 5)

- The feature status chips (`StockStatusChip`, `SalesStatusChip`, `PurchaseStatusChip`, `PaymentStatusChip`) and the feature screens still use the old widgets; migrating them page by page is Phase 5 work.
- `AppDimensions` is still used by 38 files.
- Nothing was compiled or run (no Flutter SDK available). Tests added: `test/shared/presentation/widgets/app_widgets_test.dart`.
