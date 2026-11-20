import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';

DateTime _day(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// A tax system for a country (GST, VAT, sales tax, ...).
final class TaxRegime {
  /// Creates a regime.
  const TaxRegime({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    this.description,
    this.isActive = true,
  });

  /// Identifier.
  final String id;

  /// Display name.
  final String name;

  /// ISO country code the regime belongs to.
  final String countryCode;

  /// Currency the regime reports in.
  final String currencyCode;

  /// Optional help text.
  final String? description;

  /// Whether the regime can be used.
  final bool isActive;
}

/// A place taxes can differ by: a country, state, province, county, city.
final class TaxJurisdiction {
  /// Creates a jurisdiction.
  const TaxJurisdiction({
    required this.id,
    required this.regimeId,
    required this.countryCode,
    required this.jurisdictionType,
    this.regionCode,
    this.regionName,
    this.parentJurisdictionId,
    this.isActive = true,
  });

  /// Identifier.
  final String id;

  /// Owning regime.
  final String regimeId;

  /// ISO country code.
  final String countryCode;

  /// Region code within the country (for example a state code).
  final String? regionCode;

  /// Region name.
  final String? regionName;

  /// Level of this jurisdiction.
  final JurisdictionType jurisdictionType;

  /// The containing jurisdiction, if any.
  final String? parentJurisdictionId;

  /// Whether the jurisdiction can be used.
  final bool isActive;
}

/// A class of goods or services that share tax treatment.
final class TaxCategory {
  /// Creates a category.
  const TaxCategory({
    required this.id,
    required this.name,
    required this.code,
    required this.defaultTaxTreatment,
    this.description,
    this.isActive = true,
  });

  /// Identifier.
  final String id;

  /// Display name.
  final String name;

  /// Short unique code.
  final String code;

  /// Optional help text.
  final String? description;

  /// Treatment unless a transaction overrides it.
  final TaxTreatment defaultTaxTreatment;

  /// Whether the category can be used.
  final bool isActive;
}

/// A named set of rules for one regime.
final class TaxProfile {
  /// Creates a profile.
  const TaxProfile({
    required this.id,
    required this.name,
    required this.regimeId,
    this.description,
    this.isDefault = false,
    this.defaultTaxCategoryId,
    this.isActive = true,
  });

  /// Identifier.
  final String id;

  /// Display name.
  final String name;

  /// The regime the profile's rules belong to.
  final String regimeId;

  /// Optional help text.
  final String? description;

  /// Whether this is the profile used when none is chosen.
  final bool isDefault;

  /// Category inherited by products that have none assigned.
  final String? defaultTaxCategoryId;

  /// Whether the profile can be used.
  final bool isActive;
}

/// An explicit, named, traceable replacement of a product's tax category.
final class TaxOverride {
  /// Creates an override.
  const TaxOverride({
    required this.id,
    required this.name,
    required this.taxCategoryId,
    required this.reason,
    this.isActive = true,
  });

  /// Identifier.
  final String id;

  /// Display name.
  final String name;

  /// The category products with this override use instead.
  final String taxCategoryId;

  /// Why the override exists (required for traceability).
  final String reason;

  /// Whether the override can be used.
  final bool isActive;
}

/// Says which components apply in which context.
final class TaxRule {
  /// Creates a rule.
  const TaxRule({
    required this.id,
    required this.taxProfileId,
    required this.taxCategoryId,
    required this.calculationMethod,
    required this.effectiveFrom,
    this.jurisdictionId,
    this.transactionType,
    this.customerTaxStatus,
    this.supplyType,
    this.supplyRelation = SupplyRelation.any,
    this.isStackable = false,
    this.effectiveUntil,
    this.priority = 0,
    this.isActive = true,
  });

  /// Identifier.
  final String id;

  /// Owning profile.
  final String taxProfileId;

  /// Category the rule applies to.
  final String taxCategoryId;

  /// Jurisdiction the rule applies in (including everything inside it);
  /// `null` means everywhere in the regime.
  final String? jurisdictionId;

  /// Transaction type the rule applies to; `null` means any.
  final TaxTransactionType? transactionType;

  /// Customer tax status the rule applies to (for example `registered`);
  /// `null` means any. Free text so regimes can define their own.
  final String? customerTaxStatus;

  /// Supply type the rule applies to (for example `goods`); `null` = any.
  final String? supplyType;

  /// Required relation between seller and place of supply.
  final SupplyRelation supplyRelation;

  /// How the rule's components compute tax.
  final TaxCalculationMethod calculationMethod;

  /// A stackable rule is applied together with the winning rule (for
  /// example a county tax added to a state tax) instead of competing.
  final bool isStackable;

  /// First day the rule applies (inclusive).
  final DateTime effectiveFrom;

  /// Last day the rule applies (inclusive); `null` means open-ended.
  final DateTime? effectiveUntil;

  /// Higher priority wins among competing rules.
  final int priority;

  /// Whether the rule can be used.
  final bool isActive;

  /// Whether the rule applies on [date] (compared by calendar day).
  bool isEffectiveOn(DateTime date) {
    final day = _day(date);
    if (day.isBefore(_day(effectiveFrom))) {
      return false;
    }
    final until = effectiveUntil;
    return until == null || !day.isAfter(_day(until));
  }

  /// How many of the optional selectors the rule sets: a more specific
  /// rule beats a more general one at equal priority.
  int get selectorCount =>
      (transactionType == null ? 0 : 1) +
      (customerTaxStatus == null ? 0 : 1) +
      (supplyType == null ? 0 : 1) +
      (supplyRelation == SupplyRelation.any ? 0 : 1);
}

/// One tax line produced by a rule (CGST, VAT, a cess, ...).
final class TaxComponent {
  /// Creates a component.
  const TaxComponent({
    required this.id,
    required this.taxRuleId,
    required this.name,
    required this.componentType,
    required this.calculationOrder,
    this.rateBasisPoints = 0,
    this.fixedAmountMinor,
    this.isCompound = false,
    this.isRecoverable = false,
    this.isActive = true,
  });

  /// Identifier.
  final String id;

  /// Owning rule.
  final String taxRuleId;

  /// Display name (printed on documents).
  final String name;

  /// Open-ended type.
  final TaxComponentType componentType;

  /// Rate in basis points (1% = 100); used by percentage rules.
  final int rateBasisPoints;

  /// Amount per unit in minor currency units; used by fixed rules.
  final int? fixedAmountMinor;

  /// Position in the calculation (ascending).
  final int calculationOrder;

  /// Whether the component is calculated on the base plus the components
  /// before it.
  final bool isCompound;

  /// Whether the tax paid on purchases can be claimed back.
  final bool isRecoverable;

  /// Whether the component can be used.
  final bool isActive;
}
