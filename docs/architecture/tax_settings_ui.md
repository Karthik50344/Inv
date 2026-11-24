# Tax settings and product tax screens (Checkpoint E)

## Writing the tax configuration
`TaxConfigEditor` (`features/taxation/domain/usecases`) creates and edits regimes, places, categories, profiles, overrides, rules and components. Each save: `TaxConfigValidator` checks it against the rest of the configuration, then the change and an audit event (type `tax_regime`, `tax_category`, ..., with only the changed fields as before/after) commit in one transaction. A save that changes nothing records nothing. Records are **switched off, never deleted**, so every rule that ever applied stays traceable; posted documents keep their own snapshot regardless.

Checks include: country and currency codes, category code unique, parent places cannot loop, an override must say why, rules cannot be dated backwards, a category that never charges tax (exempt, zero rated, out of scope) takes no rule, percentage rates 0-1000%, fixed amounts per unit, no two tax lines with the same name and type in one rule, and **a rule that is identical to another active rule in everything that decides which wins, with overlapping dates and equal priority, is refused**. Rules that differ in their selectors can still tie for some transactions; that is reported when a calculation runs (see `tax_engine.md`). The default profile and the default category of a profile cannot be switched off.

Business-level preferences (`tax_country_code`, `tax_region_code`, `tax_seller_registered`) are edited by the same class and audited as `tax_preferences`.

## Screens (More > System > Tax settings, `/more/tax`)
| Screen | Purpose |
|---|---|
| Tax settings | What is in use now, a "To check" list (no profile, charging categories without a rule, rules without tax lines, country not set), counts, entry to each list |
| Tax systems / Places / Tax profiles / Tax categories / Product overrides | Lists with add, edit and switch off; forms in bottom sheets with field-level errors |
| Tax rules, Tax rule | Rules list; the rule page shows its conditions and its tax lines (CGST 9%, SGST 9%, fixed per-unit amounts) with add, edit, switch off |
| Calculation preferences | Country, state, registered or not |

Rates are typed as percentages (up to two decimals) and stored as basis points; fixed amounts follow the active currency's decimal places. **Inventrix ships no tax rates**: the screens say so, and the owner enters what their advisor gives.

## Product screen (product details > percent icon)
Shows how the product is taxed (assigned / inherited from the profile / explicit override, and the treatment), lets the owner choose a category and an override (`SetProductTaxTreatment`: both must exist and be active; audited with before/after and flagged as a tax change), and manages classification codes: add (HSN / SAC / HS / own system), edit, make primary, remove (posted invoices keep their copy), plus offline suggestions from codes already used. The form checks shape only and never fills in or looks up a code.

## Audit operator name
Audit & export dashboard > "Named on new events" sets the local operator name (`SaveAuditOperatorName`, audited with old and new value). Events carry it as an unverified local operator.

## Known limits
- The older single-rate tax-rate screens still exist and still edit `tax_rates`; products without a category keep using them. Choosing a category on the product screen switches that product to the new system.
- The place of supply is the business location until customers have locations.
- There is no bulk assignment of categories to many products yet.
