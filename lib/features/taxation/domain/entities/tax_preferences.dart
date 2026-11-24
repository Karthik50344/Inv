/// Business-level tax settings the calculation needs (stored in the app
/// settings, not in the tax tables).
final class TaxPreferences {
  /// Creates the preferences.
  const TaxPreferences({
    this.countryCode,
    this.regionCode,
    this.sellerRegistered = true,
  });

  /// Country of the business (ISO, upper case), if set.
  final String? countryCode;

  /// State or region of the business, if set.
  final String? regionCode;

  /// Whether the business is registered for the tax. When false, sales are
  /// treated as out of scope (no tax charged).
  final bool sellerRegistered;
}

/// The kinds of tax configuration records that can be edited.
enum TaxConfigKind {
  /// A tax regime.
  regime('tax_regime', 'tax_regimes'),

  /// A jurisdiction.
  jurisdiction('tax_jurisdiction', 'tax_jurisdictions'),

  /// A tax category.
  category('tax_category', 'tax_categories'),

  /// A tax profile.
  profile('tax_profile', 'tax_profiles'),

  /// A product tax override.
  override('tax_override', 'tax_overrides'),

  /// A tax rule.
  rule('tax_rule', 'tax_rules'),

  /// A tax component.
  component('tax_component', 'tax_components');

  const TaxConfigKind(this.entityType, this.table);

  /// Audit record type.
  final String entityType;

  /// Database table.
  final String table;
}
