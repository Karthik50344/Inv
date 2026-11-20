# Configurable tax engine (Checkpoint A)

Code: `lib/features/taxation/`. Pure Dart in `domain/`; Drift only in `data/`.

## Model
`TaxRegime` > `TaxJurisdiction` (tree) · `TaxCategory` (class of goods, default treatment) · `TaxProfile` (set of rules for a regime, optional default category) · `TaxOverride` (named, reasoned replacement of a product's category) · `TaxRule` (when it applies) · `TaxComponent` (the tax lines). Component and jurisdiction types are open-ended value objects, not enums.

Extra fields beyond the spec, and why: `TaxRule.supplyRelation` (intra/inter/cross-border selector, so CGST+SGST and IGST never co-apply), `TaxRule.isStackable` (county tax added to state tax), `TaxRule.jurisdictionId` is nullable (null = whole regime), `TaxComponent.fixedAmountMinor` (per-unit fixed taxes), `TaxProfile.defaultTaxCategoryId` (what products inherit).

## Product category
`ProductTaxClassifier`: explicit override, else the product's category, else the profile default, else a failure. Source is returned so the UI can say "inherited / assigned / override". Products store no tax amount.

## Rule resolution (deterministic)
1. Profile and category exist and are active.
2. Treatment = input override, else category default. A seller not registered for the tax does not charge it on sales (`out_of_scope`); override this per country by adding a provider. Exempt, zero-rated and out-of-scope need no rule: zero tax, treatment recorded.
3. Candidate rules: active, same profile/category, effective that day (inclusive, by calendar date), matching transaction type, customer status, supply type and supply relation (null matches anything), located at or above the place of supply.
4. Best non-stackable rule by (priority, selector count, jurisdiction depth). A tie is `TaxRuleConflictFailure`. All stackable candidates also apply. The same component name+type from two rules is a conflict.
5. No candidate: `TaxConfigurationFailure`. **Never silent 0%.**

`JurisdictionRuleProvider` holds country context logic (relation, required inputs, whether tax is charged). Provided: a neutral default and an `IndiaGstRuleProvider` that only demands seller and place-of-supply states. No rates and no statutory completeness are claimed for any country.

## Arithmetic
Integer minor units, BigInt intermediates, half away from zero, no `double`. Exclusive: each component rounded once. Inclusive: net derived by exactly inverting the component chain (`total = net(1+a)+b`), components computed forward, last component absorbs the rounding remainder, so `net + sum(components) = total`. Compound components use base + earlier tax. Reverse charge: net = price, tax reported separately and not added. With one component the results equal `LineCalculator` (tested).

## Snapshots
`TaxCalculationResult` is immutable and holds regime, profile, category, treatment, rule ids, per-component name/type/rate/base/amount, pricing mode, date and place of supply. Persisting it onto posted documents is Checkpoint B.

## Checkpoint B: classification and invoice integration
- `features/product_classification`: `ProductClassification`, open `ClassificationSystem` (HSN, SAC, HS, custom), `ClassificationValidator` (shape only: digit counts, SAC = services, HSN/HS = goods; never checks that a code exists, never invents one, no network), add/update/remove/set-primary use cases, offline search over codes already entered. Removing a classification never affects posted invoices (they hold a snapshot).
- Lines: `SalesLineBuilder` / `PurchaseLineBuilder` call `TaxLineService` when the product has a tax category or override **and** a default tax profile exists; otherwise the old single-rate path runs unchanged. The service resolves the category (`ProductTaxClassifier`), runs the engine and returns amounts, a `LineTaxSnapshot` and the legacy `tax_rate_bp` (sum of percentage components) and `tax_name` ("CGST + SGST").
- Context: default active tax profile; seller country/region from `app_settings` keys `tax_country_code`, `tax_region_code` (else the regime's country, `XX` becomes `ZZ`); `tax_seller_registered` = `false` makes sales out of scope. The place of supply equals the seller location until customer locations are recorded.
- Snapshot: frozen when the draft is saved (JSON on the item + per-component rows), immutable once posted (triggers). Re-saving a draft recomputes it. The classification printed is the product's primary one at that moment.
- Invoice layout: an HSN/SAC (or `Code`) column appears only when some line has a classification; engine-taxed lines list tax per component (for example CGST 9%, SGST 9%); reverse-charge tax is shown separately. Invoices without these print exactly as before.
- Product edits: the old form keeps a product's category and override; changing its single tax rate clears the category so the new rate applies (`ProductDraft.taxClassificationEdited` is the hook for the new UI).

## Not done yet
Product form fields for tax category / override and the classification section, tax settings screens, HSN/SAC-wise and tax-summary reports, classification display on product details, audit of tax and classification changes. Until the tax settings screens exist the configuration can only be created by the 9 to 10 carry-over or by SQL; new rates added on the old tax-rate screen live in `tax_rates` only and are used by products through the single-rate path. Posting does not re-validate a stale draft against changed tax rules.
