import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';

/// Country-specific behaviour the generic engine must not hardcode.
///
/// A provider answers *context* questions (how do seller and place of supply
/// relate, is the input complete, is tax charged at all). It never contains
/// rates: rates live in configurable rules. Add a provider per country when
/// its legal rules are implemented and validated; do not claim compliance
/// for a country without one.
abstract interface class JurisdictionRuleProvider {
  /// Whether this provider handles a seller in [countryCode].
  bool supports(String countryCode);

  /// Seller / place-of-supply relation used to select rules.
  SupplyRelation relationOf(TaxCalculationInput input);

  /// A failure when [input] lacks data the country's rules need.
  Failure? validate(TaxCalculationInput input);

  /// Whether tax is charged on this transaction at all.
  bool chargesTax(TaxCalculationInput input);
}

/// Neutral behaviour used when no country provider applies.
class DefaultJurisdictionRuleProvider implements JurisdictionRuleProvider {
  /// Creates the provider.
  const DefaultJurisdictionRuleProvider();

  @override
  bool supports(String countryCode) => true;

  @override
  SupplyRelation relationOf(TaxCalculationInput input) {
    final seller = input.sellerLocation;
    final place = input.placeOfSupply;
    if (seller.countryCode != place.countryCode) {
      return SupplyRelation.crossBorder;
    }
    final sellerRegion = seller.regionCode;
    final placeRegion = place.regionCode;
    if (sellerRegion == null || placeRegion == null) {
      return SupplyRelation.any;
    }
    return sellerRegion == placeRegion
        ? SupplyRelation.intra
        : SupplyRelation.inter;
  }

  @override
  Failure? validate(TaxCalculationInput input) => null;

  /// A seller who is not registered for the tax does not charge it on sales.
  /// Purchases and returns are unaffected.
  @override
  bool chargesTax(TaxCalculationInput input) =>
      input.transactionType != TaxTransactionType.sale ||
      input.isSellerTaxRegistered;
}

/// Data checks for supplies within India.
///
/// It only requires the information that intra-/inter-state rules depend
/// on. It carries no rates and does not claim statutory completeness.
final class IndiaGstRuleProvider extends DefaultJurisdictionRuleProvider {
  /// Creates the provider.
  const IndiaGstRuleProvider();

  @override
  bool supports(String countryCode) => countryCode == 'IN';

  @override
  Failure? validate(TaxCalculationInput input) {
    final place = input.placeOfSupply;
    if (place.countryCode != 'IN') {
      return null;
    }
    if (input.sellerLocation.regionCode == null || place.regionCode == null) {
      return const ValidationFailure(
        'Choose the seller state and the place of supply state: GST depends '
        'on whether they are the same.',
      );
    }
    return null;
  }
}
