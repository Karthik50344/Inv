import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// A place: a country, optionally a region, optionally a known
/// jurisdiction id.
final class TaxLocation {
  /// Creates a location.
  const TaxLocation({
    required this.countryCode,
    this.regionCode,
    this.jurisdictionId,
  });

  /// ISO country code.
  final String countryCode;

  /// Region code within the country.
  final String? regionCode;

  /// Explicit jurisdiction, when already known.
  final String? jurisdictionId;

  @override
  String toString() => regionCode == null
      ? countryCode
      : '$countryCode-$regionCode';
}

/// Everything the engine needs to tax one line.
final class TaxCalculationInput {
  /// Creates an input.
  const TaxCalculationInput({
    required this.taxProfileId,
    required this.taxCategoryId,
    required this.transactionType,
    required this.transactionDate,
    required this.pricingMode,
    required this.sellerLocation,
    required this.placeOfSupply,
    required this.grossAmount,
    required this.quantity,
    this.buyerLocation,
    this.customerTaxStatus,
    this.supplyType,
    this.isSellerTaxRegistered = true,
    this.discount,
    this.treatmentOverride,
    this.overrideReference,
  });

  /// Profile whose rules apply.
  final String taxProfileId;

  /// Effective category of the product (see `ProductTaxClassifier`).
  final String taxCategoryId;

  /// Kind of transaction.
  final TaxTransactionType transactionType;

  /// Date the transaction is taxed on (decides the effective rules).
  final DateTime transactionDate;

  /// Whether [grossAmount] contains tax.
  final PricingMode pricingMode;

  /// Where the seller is.
  final TaxLocation sellerLocation;

  /// Where the buyer is, if known.
  final TaxLocation? buyerLocation;

  /// Where the supply is taxed.
  final TaxLocation placeOfSupply;

  /// Unit price x quantity, before discount.
  final Money grossAmount;

  /// Quantity (needed by fixed per-unit components).
  final Quantity quantity;

  /// Discount amount already resolved to money; `null` means none.
  final Money? discount;

  /// Customer tax status (for example `registered`), if known.
  final String? customerTaxStatus;

  /// Supply type (for example `goods` or `services`), if known.
  final String? supplyType;

  /// Whether the seller is registered for this tax.
  final bool isSellerTaxRegistered;

  /// Forces a treatment (for example an exemption certificate).
  final TaxTreatment? treatmentOverride;

  /// Why the override applies (certificate number, note); recorded.
  final String? overrideReference;
}

/// Tax computed by one component for one line.
final class TaxComponentResult {
  /// Creates a component result.
  const TaxComponentResult({
    required this.ruleId,
    required this.componentId,
    required this.name,
    required this.type,
    required this.method,
    required this.taxableAmount,
    required this.amount,
    required this.calculationOrder,
    required this.isCompound,
    required this.isRecoverable,
    this.rateBasisPoints,
    this.fixedAmount,
  });

  /// Rule that produced it.
  final String ruleId;

  /// Component that produced it.
  final String componentId;

  /// Component name at calculation time.
  final String name;

  /// Component type at calculation time.
  final TaxComponentType type;

  /// How it was calculated.
  final TaxCalculationMethod method;

  /// Rate in basis points (percentage components).
  final int? rateBasisPoints;

  /// Per-unit amount (fixed components).
  final Money? fixedAmount;

  /// Base the component was applied to.
  final Money taxableAmount;

  /// Tax amount.
  final Money amount;

  /// Position in the calculation.
  final int calculationOrder;

  /// Whether it was compounded on earlier components.
  final bool isCompound;

  /// Whether the tax can be claimed back on purchases.
  final bool isRecoverable;
}

/// The outcome of taxing one line: enough to freeze as a snapshot.
final class TaxCalculationResult {
  /// Creates a result.
  const TaxCalculationResult({
    required this.taxProfileId,
    required this.regimeId,
    required this.taxCategoryId,
    required this.treatment,
    required this.pricingMode,
    required this.transactionDate,
    required this.placeOfSupply,
    required this.supplyRelation,
    required this.grossAmount,
    required this.discount,
    required this.taxableAmount,
    required this.components,
    required this.taxCharged,
    required this.reverseChargeTax,
    required this.totalAmount,
    required this.ruleIds,
    this.treatmentReason,
    this.jurisdictionIds = const [],
  });

  /// Profile used.
  final String taxProfileId;

  /// Regime of the profile.
  final String regimeId;

  /// Category used.
  final String taxCategoryId;

  /// Treatment that applied.
  final TaxTreatment treatment;

  /// Why the treatment differs from the category default, if it does.
  final String? treatmentReason;

  /// Pricing mode used.
  final PricingMode pricingMode;

  /// Date the transaction was taxed on.
  final DateTime transactionDate;

  /// Place of supply used.
  final TaxLocation placeOfSupply;

  /// Seller / place-of-supply relation that was derived.
  final SupplyRelation supplyRelation;

  /// Amount before discount.
  final Money grossAmount;

  /// Discount applied.
  final Money discount;

  /// Value excluding tax (the cost or revenue base).
  final Money taxableAmount;

  /// Per-component results, in calculation order.
  final List<TaxComponentResult> components;

  /// Tax added to what the buyer pays.
  final Money taxCharged;

  /// Tax computed under reverse charge (not charged on the invoice).
  final Money reverseChargeTax;

  /// [taxableAmount] plus [taxCharged].
  final Money totalAmount;

  /// Rules that contributed components.
  final List<String> ruleIds;

  /// Jurisdictions of the contributing rules.
  final List<String> jurisdictionIds;

  /// Tax the business can claim back (recoverable components).
  Money get recoverableTax {
    var total = Money.zero(
      currencyCode: taxCharged.currencyCode,
      decimalPlaces: taxCharged.decimalPlaces,
    );
    for (final c in components) {
      if (c.isRecoverable) {
        total += c.amount;
      }
    }
    return total;
  }
}

/// One line of a [TaxBreakdown].
final class TaxBreakdownLine {
  /// Creates a line.
  const TaxBreakdownLine({
    required this.name,
    required this.type,
    required this.taxableAmount,
    required this.amount,
    this.rateBasisPoints,
  });

  /// Component name.
  final String name;

  /// Component type.
  final TaxComponentType type;

  /// Rate in basis points, when percentage based.
  final int? rateBasisPoints;

  /// Sum of the bases.
  final Money taxableAmount;

  /// Sum of the tax.
  final Money amount;
}

/// Component totals over several lines, grouped by name, type and rate.
final class TaxBreakdown {
  /// Creates a breakdown.
  const TaxBreakdown(this.lines);

  /// Groups the components of [results].
  factory TaxBreakdown.fromResults(Iterable<TaxCalculationResult> results) {
    final grouped = <String, TaxBreakdownLine>{};
    for (final result in results) {
      for (final c in result.components) {
        final key = '${c.name}|${c.type.code}|${c.rateBasisPoints}';
        final existing = grouped[key];
        grouped[key] = existing == null
            ? TaxBreakdownLine(
                name: c.name,
                type: c.type,
                rateBasisPoints: c.rateBasisPoints,
                taxableAmount: c.taxableAmount,
                amount: c.amount,
              )
            : TaxBreakdownLine(
                name: c.name,
                type: c.type,
                rateBasisPoints: c.rateBasisPoints,
                taxableAmount: existing.taxableAmount + c.taxableAmount,
                amount: existing.amount + c.amount,
              );
      }
    }
    return TaxBreakdown(grouped.values.toList());
  }

  /// The grouped lines.
  final List<TaxBreakdownLine> lines;
}
