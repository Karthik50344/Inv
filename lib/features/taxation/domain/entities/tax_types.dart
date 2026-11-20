/// How a product or transaction is treated for tax.
enum TaxTreatment {
  /// Taxed at the regular rate.
  standardRated('standard_rated', 'Standard rated'),

  /// Taxed at a reduced rate.
  reducedRated('reduced_rated', 'Reduced rated'),

  /// Taxable, but the rate is zero (the sale is still reported).
  zeroRated('zero_rated', 'Zero rated'),

  /// Not taxable by law.
  exempt('exempt', 'Exempt'),

  /// Outside the scope of the tax.
  outOfScope('out_of_scope', 'Out of scope'),

  /// Tax is computed but accounted for by the buyer, not charged on the
  /// invoice.
  reverseCharge('reverse_charge', 'Reverse charge');

  const TaxTreatment(this.code, this.label);

  /// Stable storage code.
  final String code;

  /// Name shown to users.
  final String label;

  /// Whether tax amounts are computed from rule components.
  bool get computesTax =>
      this == standardRated || this == reducedRated || this == reverseCharge;

  /// Whether computed tax is added to what the buyer pays.
  bool get chargesTax => this == standardRated || this == reducedRated;

  /// The treatment stored as [code], or `null`.
  static TaxTreatment? tryParse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return null;
  }
}

/// The kind of business transaction being taxed.
enum TaxTransactionType {
  /// A sale to a customer.
  sale('sale'),

  /// A purchase from a supplier.
  purchase('purchase'),

  /// Goods returned by a customer.
  salesReturn('sales_return'),

  /// Goods returned to a supplier.
  purchaseReturn('purchase_return');

  const TaxTransactionType(this.code);

  /// Stable storage code.
  final String code;

  /// The type stored as [code], or `null`.
  static TaxTransactionType? tryParse(String? code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return null;
  }
}

/// Whether the entered price already contains tax.
enum PricingMode {
  /// Price includes tax.
  inclusive('inclusive'),

  /// Tax is added on top of the price.
  exclusive('exclusive');

  const PricingMode(this.code);

  /// Stable storage code.
  final String code;
}

/// How a rule's components compute tax.
enum TaxCalculationMethod {
  /// A percentage (basis points) of the taxable amount.
  percentage('percentage'),

  /// A fixed amount per unit.
  fixed('fixed');

  const TaxCalculationMethod(this.code);

  /// Stable storage code.
  final String code;

  /// The method stored as [code], or `null`.
  static TaxCalculationMethod? tryParse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return null;
  }
}

/// How the seller's location relates to the place of supply.
enum SupplyRelation {
  /// Matches regardless of location (also the value when unknown).
  any('any'),

  /// Same region (for example the same state).
  intra('intra'),

  /// Same country, different region.
  inter('inter'),

  /// Different countries.
  crossBorder('cross_border');

  const SupplyRelation(this.code);

  /// Stable storage code.
  final String code;

  /// The relation stored as [code]; unknown codes become [any].
  static SupplyRelation parse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return any;
  }
}

/// Where a product's effective tax category came from.
enum TaxCategorySource {
  /// A tax override explicitly chosen for the product.
  explicitOverride('Explicit tax override'),

  /// The category assigned to the product.
  productAssignment('Assigned to the product'),

  /// Inherited from the active tax profile's default.
  profileDefault('Inherited from the tax profile');

  const TaxCategorySource(this.label);

  /// Name shown to users.
  final String label;
}

/// An open-ended tax component type (CGST, VAT, PST, a custom levy, ...).
///
/// A value object rather than an enum so new tax types need no code change.
final class TaxComponentType {
  /// Creates a type from its stable [code].
  const TaxComponentType(this.code);

  /// Central goods and services tax.
  static const TaxComponentType cgst = TaxComponentType('cgst');

  /// State goods and services tax.
  static const TaxComponentType sgst = TaxComponentType('sgst');

  /// Integrated goods and services tax.
  static const TaxComponentType igst = TaxComponentType('igst');

  /// Union territory goods and services tax.
  static const TaxComponentType utgst = TaxComponentType('utgst');

  /// Value added tax.
  static const TaxComponentType vat = TaxComponentType('vat');

  /// Sales tax.
  static const TaxComponentType salesTax = TaxComponentType('sales_tax');

  /// Goods and services tax.
  static const TaxComponentType gst = TaxComponentType('gst');

  /// Harmonized sales tax.
  static const TaxComponentType hst = TaxComponentType('hst');

  /// Provincial sales tax.
  static const TaxComponentType pst = TaxComponentType('pst');

  /// Quebec sales tax.
  static const TaxComponentType qst = TaxComponentType('qst');

  /// Cess or another surcharge.
  static const TaxComponentType cess = TaxComponentType('cess');

  /// Any user-defined tax.
  static const TaxComponentType custom = TaxComponentType('custom');

  /// Stable storage code.
  final String code;

  @override
  bool operator ==(Object other) =>
      other is TaxComponentType && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// An open-ended jurisdiction level (country, state, province, county, ...).
final class JurisdictionType {
  /// Creates a type from its stable [code].
  const JurisdictionType(this.code);

  /// A country.
  static const JurisdictionType country = JurisdictionType('country');

  /// A state.
  static const JurisdictionType state = JurisdictionType('state');

  /// A province.
  static const JurisdictionType province = JurisdictionType('province');

  /// A union territory.
  static const JurisdictionType unionTerritory = JurisdictionType(
    'union_territory',
  );

  /// A county.
  static const JurisdictionType county = JurisdictionType('county');

  /// A city.
  static const JurisdictionType city = JurisdictionType('city');

  /// Any other level.
  static const JurisdictionType other = JurisdictionType('other');

  /// Stable storage code.
  final String code;

  @override
  bool operator ==(Object other) =>
      other is JurisdictionType && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
