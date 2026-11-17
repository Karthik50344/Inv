# Settings & business configuration (Phase 11)

Screens: **More -> Settings** (home with inline switches), *Business profile*, *Currency and formats*, *Tax rates*, *Document numbering*; default payment method lives on the existing *Payment methods* screen.

## What is configurable

| Area | Where stored | Notes |
|---|---|---|
| Business name, address, phone, e-mail, tax number, logo | `business_profiles` (single row) | Printed on invoice PDFs (logo too). Posted invoices keep their own amounts and parties. |
| Currency + decimal places | `app_settings` `currency_code`, `currency_decimal_places` | Locked while amounts without their own currency exist (see below). |
| Date style, number style | `date_style`, `number_style` | Display only. Styles: `d MMM yyyy`, `dd/MM/yyyy`, `MM/dd/yyyy`, `yyyy-MM-dd`; `12,34,567.89`, `1,234,567.89`, `1.234.567,89`, `1 234 567,89`. |
| Theme | `theme_mode` | system / light / dark, applied to `MaterialApp.themeMode`. |
| Approval for sales / purchases | `sales_approval_required`, `purchase_approval_required` | Toggles are audited. |
| Tax rates | `tax_rates` | Add, rename, edit percentage (only while unused), archive/restore. |
| Default tax rate and "prices include tax" for new products | `default_tax_rate_id`, `default_price_includes_tax` | Used by the new-product form only. |
| Default payment method | `default_payment_method_id` | Preselected in payment and expense forms when still active. |
| Document prefix per kind, digits | `numbering.prefix.<sequence_key>`, `numbering.padding` | Applied at posting time. |
| Next document number | `document_sequences.last_value` | Can only move forward. |
| Backup reminder (off / 7 / 14 / 30 days) | `backup_reminder_days` | Banner on the Backup screen when no exported backup is that recent. |

No schema change: everything uses existing tables (`app_settings`, `business_profiles`, `tax_rates`, `document_sequences`). Keys are constants in `SettingKeys` / `NumberingSettingKeys` and must never be renamed.

## Rules that protect history

1. **Currency lock.** Invoices, payments, returns and expenses store their own currency; product prices, opening balances, stock costs/values carry none, and posted invoices can only be settled in the active currency. While any of these exists (`MoneyLock`: priced products, non-zero opening balances, costed stock, posted invoices with an amount) the currency **and decimal places** cannot change, because `12.50` stored as `1250` would silently become `1250`. The check and the save run in one transaction. Choose the currency before entering prices.
2. **Numbering.** The prefix is read when a document is posted (`DocumentSequenceRepository.nextNumber`, same transaction as the counter), so issued numbers never change. Counters are never reset or lowered (`MAX` upsert). A prefix is 1-10 characters of letters, digits and `- _ / .` and **must not end in a digit**; with that rule (prefix, counter) -> text is injective, so a prefix change can never recreate an old number. Every document kind needs a different prefix (case-insensitive). The unique indexes on the number columns remain the last line of defence.
3. **Tax rates.** Invoice lines snapshot their rate, so history is safe. A rate used by products or expenses keeps its percentage (create a new rate and archive the old one); the name can always change. Archiving the default rate clears the default.
4. **Display formats** never touch stored values or calculations. They are held in `DisplayFormats` and read by `MoneyFormatter`/`DateFormatter` when formatting; after a change `FormatRefresher` marks the existing widget tree dirty so open screens redraw without losing state.
5. **Audit.** Business profile, currency, numbering, counter moves, approval toggles and tax-rate edits write `audit_logs` rows (`entity_type` `settings` or `tax_rate`). The summaries never contain personal details.

## Logo

Copied into `<documents>/product_images/logo_*.png|jpg` (<= 5 MB). That folder is already in every backup, so no archive-format change was needed. Only `logo_*` files in that folder are ever deleted (when the logo is replaced after a successful save). A damaged logo is skipped on the PDF.

## Architecture

- Domain (`features/settings/domain`): `AppPreferences`, `NumberingSettings`, `MoneyLock`, `CurrencyCatalog`; contracts `PreferencesRepository`, `BusinessProfileRepository`, `CurrencyRepository`, `NumberingRepository`, `LogoStorage`; use cases `SaveBusinessProfile`, `ChangeCurrency`, `UpdatePreferences`, `SaveNumbering`, `SetNextDocumentNumber`, `UpdateTaxRate`, `SetTaxRateArchived`, `SetDefaultTaxRate`.
- Shared: `DocumentKind`, `DocumentNumber` (prefix rules), `DateStyle`/`NumberStyle`/`ThemePreference`.
- `SettingsCubit` is a lazy singleton (created before the first frame so theme and formats apply immediately); `TaxRatesCubit` is a factory.
- Payments/expenses/products read the defaults through `PreferencesRepository` (optional constructor parameter: without it no default is applied).

## Not included

- Automatic/scheduled backups (only a reminder; background work is platform-specific).
- Localised UI language (the `locale` setting is legacy; number style replaced it).
- Per-document-type approval beyond sales and purchases (expenses/returns have no approval step).
