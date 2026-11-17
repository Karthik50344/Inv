# Inventrix Redesign: Phase 1 — Project and Design Audit

Date: 2026-11-17. Scope: audit only. No project files were modified.

## 0. Read this first (blockers and limits)

| # | Finding | Impact |
|---|---------|--------|
| 1 | **No Flutter or Dart SDK in my sandbox.** I cannot run `flutter pub get`, `analyze`, `test`, `build`, `dart run flutter_launcher_icons` or `flutter_native_splash:create`. | Every phase ends with code that I have *read and reasoned about* but not compiled. I will not claim a build passes. You run the verification commands and paste the output. |
| 2 | **`inv.zip` has no `android/`, `ios/`, `assets/`, or `analysis_options.yaml`.** It contains only `lib/`, `test/`, `tool/`, `docs/`, `pubspec.yaml`, `README.md`. | I can write the branding assets and the `pubspec.yaml` config, but the generators need the platform folders. Android 12+ splash config (`values-v31`, `styles.xml`) and iOS `Assets.xcassets` cannot be inspected or verified from this upload. `very_good_analysis` is a dev dependency but its rule file is missing. |
| 3 | **The project has never been compiled.** `docs/development/progress.md` says Phases 1–11 were written without a Flutter run (no `pub get`, `analyze` or `test`). Phase 12 (QA/release) was never done. | The baseline may already have analyzer errors. A redesign on top of an unverified base makes regressions hard to attribute. **Recommendation:** run `flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test` now and send me the output before Phase 3 starts. |
| 4 | **Figma access was partial.** I read the file structure and rendered screenshots of all 5 frames. I then hit the Figma MCP **Starter-plan call limit**, so I could not pull variables or exact style values. | Colors, font names and radii below are **estimated from screenshots**, not exact. Section 2 says what to confirm. |

## 1. Project analysis

**Stack.** Flutter, Dart `^3.9.2`, Material 3, GoRouter 17, flutter_bloc 9, GetIt 9, Drift 2.31 + SQLite, fl_chart, pdf, share_plus, file_picker, archive, very_good_analysis. Offline-first, no login. The Dart package is `inventrix`. The `com.rk.inventrix` application ID lives in the missing `android/` and `ios/` folders and is untouched.

**Architecture.** Feature-first Clean Architecture. 14 features (`backup, categories, customers, dashboard, expenses, inventory, payments, products, purchases, reports, returns, sales, settings, suppliers`), each split into `data/domain/presentation`. Shared code sits in `lib/shared`, infrastructure in `lib/core`, wiring in `lib/app` (router, DI, shell, runtime, theme).

**Rules the redesign must obey** (`docs/architecture/dependency_rules.md`, enforced by `tool/check_imports.dart`):
- Presentation must not import `data/` or `core/database`.
- No business rules in widgets. No BLoC reading another BLoC.
- Domain must not import Flutter.

New design-system code is presentation-only, so it is allowed. **Where it lives matters:** `lib/app/theme/` already holds the theme and `lib/shared/presentation/widgets/` holds shared widgets. I propose keeping those locations instead of the prompt's `lib/core/theme/`. `lib/core` is pure-Dart by convention here, and `check_imports.dart` treats `/lib/core/` as non-presentation.

**Quantified state of the UI layer** (from grep over `lib/`):

| Metric | Value |
|---|---|
| Presentation Dart files / lines | ~22.8k lines |
| Hardcoded `Color(0x…)` / `Colors.x` outside `app_colors.dart` | **6**, and 2 are in the PDF renderer, which is legitimate. Feature widgets already use `Theme.of`/`colorScheme` (117 usages). |
| `AppDimensions` usages | 182 |
| Raw `EdgeInsets` with numeric literals / `BorderRadius.circular(n)` | 70 / 5 |
| Shared widgets | 10 files, 623 lines in total |
| `AppBar(` usages / drawers | 46 / 0 |
| `RefreshIndicator` | 2 files |
| Dialog or bottom-sheet call sites | ~30 files |
| Chart library | `fl_chart` (2 files: `dashboard_charts.dart`, `trend_bar_chart.dart`), already using `colorScheme` and a `chartPalette()` |
| Test files | 89 `*_test.dart`, including widget tests and `test/app/theme/app_theme_test.dart` |

The good news is that there is little color debt, so the redesign is mostly re-theming plus new components, not a hunt for hardcoded values.

### 1.1 Existing theme and theme switching

- `lib/app/theme/app_colors.dart`: one seed color, `0xFF0B6E4F` (green).
- `app_theme.dart`: `ColorScheme.fromSeed` for light and dark, plus a few text weights. **No component themes** (card, input, button, dialog, nav bar, chips, etc.). The file says they were deferred.
- `app_dimensions.dart`: spacing 4/8/16/24/32, radius 8/12/16, 48 touch target, 720 wide breakpoint, 840 max content width.
- **Theme switching already exists and persists.** `ThemePreference {system, light, dark}` is stored in Drift via `SettingKeys.themeMode`, exposed by `SettingsCubit.setTheme`, and applied by `InventrixApp` through a `BlocBuilder`. The current selector is a `DropdownButton` in `settings_page.dart`. So I will reuse this and not build a new `ThemeCubit` (the prompt forbids a second state mechanism).
- `FormatRefresher` force-rebuilds the tree when the date or number style changes. It must keep working. Never been run on a device.

### 1.2 Navigation

`StatefulShellRoute` with 5 branches. Bottom `NavigationBar` on phones and `NavigationRail` at ≥720 px:

`Dashboard · Products · Inventory · Sales · More`

The **More** tab opens `MorePage` (a plain `ListTile` list from `more_destinations.dart`) leading to Purchases, Customers, Suppliers, Payments, Returns, Expenses, Reports, Backup and Settings. `ComingSoonPage` is only a fallback in the router. Every destination now has a real page.

### 1.3 Screen inventory (44 feature pages + 4 shell/runtime screens)

| Area | Screens |
|---|---|
| **Shell / runtime** (4) | `MorePage`, `ComingSoonPage`, `NotFoundPage`, `StartupFailureApp` (+ `UnavailableAppRuntime`) |
| **Dashboard** (1) | `DashboardPage` (552 lines; `_Section`, `_Tile`, `_Recent`, 7 `ChartCard`s) |
| **Products** (6) | `ProductsPage`, `ProductDetailPage`, `ProductFormPage` (new/edit), `UnitsPage`, `CategoriesPage` (+ `UnitFormDialog`, `TaxRateFormDialog`, `CategoryFormDialog`) |
| **Inventory** (4) | `InventoryPage` (also used for low-stock), `StockDetailPage`, `StockOperationPage` (adjust/opening etc.), `ReconciliationPage` (+ `StockStatusChip`) |
| **Sales** (3) | `SalesPage`, `SalesFormPage` (new/edit), `SalesDetailPage` (+ `SalesLineSheet`, `SalesTotalsCard`, `SalesStatusChip`); invoice PDF via `pdf_invoice_renderer.dart` |
| **Purchases** (3) | `PurchasesPage`, `PurchaseFormPage`, `PurchaseDetailPage` (+ `PurchaseLineSheet`, `PurchaseTotalsCard`, `PurchaseStatusChip`) |
| **Customers** (3) | `CustomersPage`, `CustomerFormPage`, `CustomerDetailPage` |
| **Suppliers** (3) | `SuppliersPage`, `SupplierFormPage`, `SupplierDetailPage` |
| **Payments** (5) | `PaymentsPage`, `PaymentFormPage`, `PaymentDetailPage`, `OutstandingPage`, `PaymentMethodsPage` (+ `PaymentDialogs`, `InvoiceSettlementCard`, `PartyBalanceCard`, `PaymentStatusChip`) |
| **Returns** (3) | `ReturnsPage`, `ReturnFormPage`, `ReturnDetailPage` |
| **Expenses** (5) | `ExpensesPage`, `ExpenseFormPage`, `ExpenseDetailPage`, `ExpenseCategoriesPage`, `ExpenseReportPage` |
| **Reports** (2) | `ReportsPage` (hub), `ReportPage` (`:kind`; `ReportView`, `PeriodChips`, `TrendBarChart`) |
| **Backup** (1) | `BackupPage` (+ `RestoreConfirmationDialog`) |
| **Settings** (5) | `SettingsPage`, `BusinessProfilePage`, `RegionalSettingsPage`, `NumberingPage`, `TaxRatesPage` |

**Existing shared widgets:** `ConfirmationDialog`, `DocumentStatusChip`, `EmptyState`, `ErrorState`, `LoadingIndicator`, `LocalDataWarningBanner`, `PartyFormFields`, `SearchField`, `StoredImage`, `VoidReasonDialog`, snackbar helper. These are the seeds for the prompt's `AppEmptyState`, `AppErrorState`, `AppConfirmationDialog`, `AppSearchField` and so on. I plan to **evolve them in place** to avoid duplicates, and add the missing ones (button, card, stat card, text field, dropdown, badge, bottom sheet, data table, currency text, filter button, section header).

**Not in the app today:** a drawer (the prompt lists `AppDrawer`; the app uses a bottom bar/rail, so I would **skip it**), a product-variants feature (not in the schema), stock transfers (not in the schema), and a customer/supplier outstanding-balance view (exists via Payments → `OutstandingPage` and `PartyBalanceCard`).

## 2. Figma inspection

**What I could do:** list the file structure and render screenshots of all 5 frames. **What I could not do:** read variables, exact hex values, font names or per-node style data (call limit reached). **Please confirm or re-export:** the exact color tokens, the numeric and heading font family, and the corner radii.

The file is **one page with 5 mobile frames (390 px wide), all dark theme**:

1. Operations Dashboard
2. Inventory & Stock Management
3. Purchasing & Orders
4. Hub & Operational Settings (the More/Settings hub)
5. Sales & Billing Invoicing (the create-sale screen)

There is **no light theme, no forms beyond create-sale, no dialogs, bottom sheets, empty or error states, no tablet layouts, and no logo or icon artwork** in the file. All of those I will have to design myself.

### Visual language (estimated from screenshots)

- **Palette.** Deep navy background (~`#0B1220`), slightly lighter navy cards (~`#141C2E`) with a thin low-contrast border, and a vivid **indigo/violet primary** (~`#5B4FE9`) for primary CTAs and selected chips. Secondary is a saturated blue. Semantic colors: green for in-stock, paid and healthy; amber/blue for partial and low; red for out-of-stock and overdue; tinted-container pills (dark red background, light red text) for alerts. The current app seed is green `#0B6E4F`, so **the brand color moves from green to indigo**.
- **Typography.** A clean geometric sans for titles and body, and a **monospace face for figures, SKUs, status pills and small uppercase section labels** (e.g. "FAST EXECUTIONS", "VALUATION LEDGER"). Money amounts are large and bold. Exact families are unverified. Fonts would need bundling (no `assets/` or font config in the upload); `google_fonts` would add a network dependency to an offline-first app, so I'd bundle the font files.
- **Shape and spacing.** 12 px page gutters, 2×2 KPI grid, rounded cards (~12–16 px), pill chips and status badges, ~44 px icon buttons, 48–56 px primary CTAs, compact "high-density" rows.
- **Components seen:** top header (logo, sync pill, search, notifications, avatar), 2×2 KPI cards, horizontal quick-action row, 7D/30D/90D segmented control, grouped bar chart, urgent-stock rows with Reorder buttons, recent-invoice rows with status pills, filter-chip carousels, stock cards with thumbnail + SKU chip + status + footer actions, PO cards with progress bars, grouped settings list with leading icon tiles and trailing badges, invoice line items with +/- steppers, order calculation card, settlement-method selector, sticky "Collect Payment" bar, floating pill dock (Scan Mode / Stock Adjustment), bottom navigation with 5 items.

### Figma vs. existing app: gaps and conflicts

| Figma element | Status in app | Handling |
|---|---|---|
| Bottom nav: Dashboard / Inventory / Sales / **Purchases** / Menu | App has Dashboard / **Products** / Inventory / Sales / More. Purchases sits under More. | **Decision needed (D1).** |
| "SYNCED", "Offline ready · 100% synced", "SQLite Engine Healthy / Ping 18 ms", "Local buffer", "Ledger TXs", "Drift Core", "Lock Terminal", "Diagnostic Logs" | **No sync, no server, no user accounts, no lock.** The app is local-only. These are invented metrics. | I will **not** fake them. Replace with real equivalents only (last backup time from `BackupHistory`, DB-present indicator), or drop. **D2.** |
| User name "Sarah Jenkins", "HUB-04", "Main Warehouse" | No user or hub concept. Business name exists (`BusinessProfile`). | Use business name and logo. |
| Barcode scanner buttons ("Scan Mode", "Barcode Camera Scanner", "Stock Count scanner", scan-to-add in sales) | The app stores and searches barcodes as text. **No camera or scanner dependency, and no scanning feature.** | A real scanner needs a new package (e.g. `mobile_scanner`) plus camera permissions in the missing platform folders. The prompt forbids decorative buttons. **D3:** add scanning (new dependency) or leave these controls out. |
| Urgent Stock Deficit list on the dashboard | `DashboardSnapshot` has low-stock **counts** only, no product list. A low-stock list exists via `/inventory/low-stock`. | Either a read-only addition to the dashboard use case (small domain change, no calculation change), or link the card to the low-stock screen. **D4.** |
| PO pipeline chips: Draft / Submitted / Partially received / "In-Transit", tracking number, estimated arrival, "Receive Stock", "Log Remaining" | App has `DocumentStatus` (draft, created, pendingApproval, approved, authorized, posted, cancelled, voided). **No shipment status, tracking, ETA, or partial receiving.** | Map pills to the real statuses only. Do not add fields. |
| Currency `$` and `MM/DD/YYYY` | Currency, decimals, date style and number style (default **Indian grouping**) are user settings. | Never hardcode a symbol. Use `MoneyFormatter`. |
| Order calculation: subtotal, discount, tax | Exists (`SalesTotalsCard`, `LineCalculator`). | Restyle only. |
| Settings hub with live badges ("288 Active", "$1,420.50", "HEALTHY") | Settings and More are plain lists. | Badges can show real counts only where cheap and already available. Otherwise omit. |
| Theme row with a three-way System/Light/Dark choice | Dropdown today. | Replace with a segmented selector bound to the existing `SettingsCubit`. |
| Floating dock, sticky pay bar, offline banner | None. | Sticky total bar fits the sales form. The "offline buffered" banner is misleading for a local-only app, so I'd drop it. |

## 3. Gaps against the prompt's requirements

| Requirement | Today | Gap |
|---|---|---|
| Design tokens (colors, type, spacing, radius, shadows) | seed color, 5 spacings, 3 radii, a few text weights | Need semantic palette for both themes, a full type scale, spacing/radius/shadow tokens, `ThemeExtension` for success/warning/info/chart/status colors (Material has no slots for these). |
| Component themes | none | `CardTheme`, `InputDecorationTheme`, buttons, `NavigationBarTheme`, `ChipTheme`, `DialogTheme`, `BottomSheetTheme`, `SnackBarTheme`, `AppBarTheme`, list tile, switch, segmented button, divider, progress. |
| Light theme as a deliberate design | derived from the same seed | Hand-tuned tonal surfaces (not all white), same indigo brand. |
| Shared components (22 listed) | 10 basic widgets | ~14 new, ~6 evolved. |
| Responsive | rail ≥720, max width 840 | Mostly fine. Audit overflow in forms and the new dense cards. |
| Theme persistence | exists | Only the selector UI changes. |
| Pull-to-refresh | 2 files | Add on list pages that load from BLoC. |
| Charts | fl_chart, uses colorScheme | Retheme with chart tokens, tooltips and empty states. |
| Branding | none | Logo set, launcher icon, splash, config, **and platform folders to apply them to** (blocker #2). |
| Fonts | system default | Bundle fonts if the Figma typography is to be matched (D5). |

## 4. Implementation plan

Each phase touches few files and ends with a short report. Phases 3 onward need your `flutter analyze/test` output to be trustworthy.

- **Phase 2: Branding.** Logo concepts, then primary, icon-only, light, dark and mono variants as SVG source plus exported PNGs in `assets/branding/`; add `flutter_launcher_icons: ^0.14.1` and `flutter_native_splash: ^2.4.1` to dev_dependencies and `pubspec.yaml` config blocks (adaptive icon foreground/background, iOS, Android 12 splash, light/dark splash); declare `assets/`. I will give the exact commands (`dart run flutter_launcher_icons`, `dart run flutter_native_splash:create`). **You run them** against a project that has `android/` and `ios/`.
- **Phase 3: Design system.** Rewrite `lib/app/theme/*` (colors, typography, spacing, radius, shadows, `AppThemeExtension`, full `ThemeData` for both themes). Keep `AppDimensions` as a compatibility shim so existing screens keep compiling. Update `app_theme_test.dart`. Replace the settings theme dropdown with the three-way selector (reuses `SettingsCubit`).
- **Phase 4: Core UI.** New shared components in `lib/shared/presentation/widgets/` (`AppButton`, `AppIconButton`, `AppTextField`, `AppDropdown`, `AppCard`, `AppStatCard`, `AppSectionHeader`, `AppBadge`, `AppChip`, `AppBottomSheet`, `AppFilterButton`, `AppCurrencyText`, `AppDataTable`, `AppDatePicker` wrapper), evolve the existing ones, and restyle `AppShell`, `MorePage`, app bars and snackbars.
- **Phase 5: Screens**, in the order the prompt gives: Dashboard → Products → Inventory → Sales (create-sale first) → Purchases → Customers → Suppliers → Expenses → Payments → Returns → Reports → Backup → Settings. **Payments, Returns and Backup are missing from the prompt's checklist but exist in the app, so I'm adding them.** Pages are restyled in place. BLoCs, use cases, repositories and the database are not touched, except possibly D4.
- **Phase 6–7: Theme, responsive and interaction pass.** Checklist per screen in light, dark and system. Update widget tests that assert on old structure.
- **Phase 8: QA.** Prepared commands and results from *your* runs: `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`, `dart run tool/check_imports.dart`, then Android/iOS builds.

## 5. Decisions I need before Phase 2/3

- **D1. Bottom navigation.** (a) Keep the app's tabs (Dashboard, Products, Inventory, Sales, More). (b) Match Figma (Dashboard, Inventory, Sales, Purchases, Menu), with Products moved under Inventory or Menu. *Default if you don't choose: keep (a), because it changes no routing.*
- **D2. Invented status metrics** (sync, ping, local buffer, lock terminal). *Default: drop them, keep real data only.*
- **D3. Barcode scanning.** Add a camera scanner (new dependency and permissions) or leave the scan controls out? *Default: leave out.*
- **D4. Dashboard "Urgent Stock Deficit" list.** Small read-only addition to the dashboard data, or link to the existing low-stock screen? *Default: link only, no domain change.*
- **D5. Fonts.** Bundle a sans + monospace pair to match Figma, or use the platform default? If you can share the exact families from Figma (or export the variables), I'll use them.
- **D6. Brand color.** Move from the current green seed to the Figma indigo? *Default: yes.*
- **D7. Platform folders.** Please re-upload the project **including `android/`, `ios/`, any `assets/`, and `analysis_options.yaml`**, or confirm Phase 2 should produce assets and config only.
