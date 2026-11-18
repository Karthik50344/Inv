# Redesign Phase 5: feature screens (groups 1-8 and Part 6 done; not compiled)

Nothing here has been compiled or run (no Flutter SDK in the authoring sandbox). Only a bracket-balance check was done on the edited files.

## Done in this pass

| Group | Screens | What changed |
|---|---|---|
| 1. Dashboard | `DashboardPage`, `dashboard_charts.dart`, `trend_bar_chart.dart`, `PeriodChips` | `AppAppBar`, pull-to-refresh, period chips as `AppChip`, hero net-sales card, `AppStatCard` KPI grids with status tones, quick actions (new sale / purchase / product / expense, each reloads the dashboard on return), "View all" links, recent documents as rows with `AppCurrencyText`, inline danger banner for load errors, empty state with an "Add your first product" button. Charts read `context.appColors.chart`, tooltips and axes follow the theme, stock-health donut uses success/warning/danger. No calculation or data change. |
| 2. Products (partial) | `ProductsPage`, `ProductDetailPage`, `ProductFormPage`, `UnitsPage`, `CategoriesPage` | App bar, `AppSearchField`, `AppChip` category filters, card rows with image, SKU, unit, price (`AppCurrencyText`), archived badge, pull-to-refresh, empty-state actions, sectioned form with `AppButton`, detail page with price cards and a details card. |
| 3. Inventory | `InventoryPage` (also the low-stock report), `StockDetailPage`, `StockOperationPage`, `ReconciliationPage`, `StockStatusChip` | Stock rows as cards with SKU, status badge, quantity and value; valuation card with low/out count pills; `AppChip` status filters; pull-to-refresh; stock detail with action buttons and a movement history card (success/danger tones instead of hard-coded green); operation form with `AppButton` and an alert card for blocked operations; reconciliation result as success/danger cards. Keys and texts used by the tests are unchanged. |
| 4. Sales | `SalesPage`, `SalesFormPage`, `SalesDetailPage`, line sheet, status chip, totals card | Invoice cards with number, customer, date, item count, total and a tone-coded status badge (`SalesStatusChip.toneFor` is reusable for other documents); form split into "Customer and dates" and "Items" with line cards, a blocked-state alert card and a save button with a spinner; detail page with a facts card, item cards, totals card and full-width workflow buttons; void dialog uses `AppButton`. Fixed the empty-state copy, which wrongly said a sale adds stock. |
| 5. Purchases | `PurchasesPage`, `PurchaseFormPage`, `PurchaseDetailPage`, line sheet, status chip, totals card | Same design as Sales, ported from the restyled Sales files with the original Sales-to-Purchases differences re-applied (supplier is required, no walk-in option, no invoice PDF, stock-adding wording). |
| 6. Customers, 7. Suppliers | list, detail and form pages of each | Rows with a brand-tinted initial tile, contact line and outstanding balance (`AppCurrencyText`) or an archived badge; detail page with a facts card, the party balance card and notes; forms with the shared save button. Suppliers were ported from the restyled Customers pages with the original differences re-applied. |
| 8. Payments | `PaymentsPage`, `PaymentFormPage`, `PaymentDetailPage`, `OutstandingPage`, `PaymentMethodsPage`, `PartyBalanceCard`, `InvoiceSettlementCard`, `PaymentStatusChip` | Payment history cards with a green/amber direction tile, signed amount and filters; form grouped into who/payment/allocation with a save button that shows a spinner; detail page with a facts card, settlement card, invoice and refund cards and Apply credit / Refund / Reverse actions; the balance and settlement cards that appear on customer, supplier, sale and purchase screens now use `AppCard` and shared buttons. |
| Cross-cutting | 11 files | Removed hard-coded `OutlineInputBorder` overrides (expense, stock operation, purchase, sales, party and void-reason forms), so every form field now follows the themed `InputDecorationTheme`. New `lib/shared/presentation/widgets/chart_style.dart`. |

## Part 6 (Returns, Expenses, Reports, Backup, Settings, dialogs)

| Area | Files | What changed |
|---|---|---|
| Returns | `ReturnsPage`, `ReturnDetailPage`, `ReturnFormPage`, `InvoiceReturnsCard` | Card rows with a tone tile, search + `AppChip` filters, pull-to-refresh, `AppFactsCard` detail with item and totals cards, form in sections (invoice, items, details, value, settlement) with `AppTextField`, `AppDropdown`, `AppDatePickerField` and a save button with spinner. |
| Expenses | list, detail, form, report, categories pages, `ExpenseCategoryDialog` | Card rows, posted-total card, `AppChip` status filters, `AppDropdown` category filter, receipts as cards, workflow `AppButton`s, report with a total stat card and category bars. |
| Reports | `ReportsPage`, `ReportPage`, `ReportView` | Toned report cards, `AppDropdown` filters, metrics as `AppStatCard`, tables as `AppDataTable`, notes in a card. |
| Backup | `BackupPage`, `RestoreConfirmationDialog` | Last-backup card with `AppButton`s, record cards, danger-toned restore dialog with a record-count box. |
| Settings | home, business profile, numbering, regional, tax rates, `ThemeModeSelector` placement | Grouped `SettingsGroup` cards; the System / Light / Dark selector sits under "Appearance". |
| Dialogs | unit, category, expense category, both tax-rate dialogs | All use the new `AppFormDialog` frame. |

New shared code: `AppFactsCard`, `AppFormDialog`, `settings_tiles.dart`; `AppDropdown` gained `helper` and `errorText`. `settings_pages_test.dart` now reads an `AppButton`.

`MorePage` was already restyled in an earlier group.

## Behaviour and test notes

- `lib/features/payments/presentation/widgets/payment_dialogs.dart` is not imported anywhere (the pages build their dialogs inline), so it was left alone. It can probably be deleted.

- Widget tests that read `tester.widget<FilledButton>(find.byKey(...))` break once a keyed button becomes an `AppButton` (the key moves to the wrapper). Updated for `save_stock_operation` and `save_sale`. Also updated `purchase_pages_test.dart`. `settings_pages_test.dart` was updated in Part 6.

- Kept every key and visible text that existing widget tests look for (`dashboard_refresh`, `dashboard_range`, `dashboard_reports`, `period_*`, `product_*`, `add_product`, `save_product`, section titles on the dashboard, "No data yet", "No products yet", "Archived").
- The empty-state buttons add new keys (`dashboard_first_product`, `empty_add_product`, `empty_add_category`).
- Uses the `(_, _)` wildcard separator syntax (Dart 3.7+; the project is on `^3.9.2`).
- fl_chart: tooltips use `getTooltipColor`, which exists in the allowed range (>=0.69).

## Verify on your machine

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test test/features/reports test/features/products test/features/categories
dart run tool/check_imports.dart
```

## Phase 6 (static theme validation, not run)

- No hardcoded colors in feature widgets. The one found (backup busy overlay) now uses `colorScheme.scrim`; PDF renderer colors are print-only and unchanged.
- Palette contrast recomputed from `app_colors.dart`: all text, status, on-color pairs and chart colors meet their targets in both themes. Input borders miss 3:1 only on the two strongest neutral fills, which no input uses.
- Added `test/shared/presentation/widgets/part6_widgets_test.dart` (AppFactsCard, AppFormDialog, SettingsGroup, AppDropdown in light and dark).
- Still needs a device/emulator pass: every screen in light, dark and system mode.

## Phase 7 (responsiveness and interaction, not run)

- New `AppContentWidth` caps page content at 840 px and centers it on tablets; applied to every Part 6 page body (backup wraps only its content, so the busy overlay still covers the screen).
- Form pages (return, expense, business profile, numbering, currency) dismiss the keyboard on scroll; dialogs scroll inside `AppFormDialog`.
- Small buttons are 40 px tall with Material's 48 px tap target.
- Added `app_content_width_test.dart` (320 px phone, 390 px phone, 1200 px tablet).
- Still needs a device pass: small phone (320 px) and large font scale on each Part 6 screen, keyboard open on each form, pull-to-refresh on lists, rotation.

## App bar update (requested after Phase 7)

`AppAppBar` now centers the title (theme `centerTitle: true` too). The start slot shows, in order: an explicit `leading`, the back/drawer button when Flutter would show one, otherwise the Inventrix symbol (light/dark variant). The symbol is hidden at 720 px and wider because the navigation rail already shows it. Pushed screens keep the back button, since a screen cannot show both in one slot. Tests: `app_app_bar_test.dart`.
