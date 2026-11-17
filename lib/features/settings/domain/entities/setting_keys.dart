/// Keys of the `app_settings` table. The values are stored on users' devices
/// and in backups: never rename them.
abstract final class SettingKeys {
  /// ISO 4217 code of the active currency.
  static const String currencyCode = 'currency_code';

  /// Number of minor-unit digits of the active currency.
  static const String currencyDecimalPlaces = 'currency_decimal_places';

  /// Legacy locale (kept for old installs; the number style replaces it).
  static const String locale = 'locale';

  /// `system`, `light` or `dark`.
  static const String themeMode = 'theme_mode';

  /// A [DateStyle] name.
  static const String dateStyle = 'date_style';

  /// A [NumberStyle] name.
  static const String numberStyle = 'number_style';

  /// `true` when purchases need approval before posting.
  static const String purchaseApproval = 'purchase_approval_required';

  /// `true` when sales need approval before posting.
  static const String salesApproval = 'sales_approval_required';

  /// Id of the payment method preselected in forms.
  static const String defaultPaymentMethodId = 'default_payment_method_id';

  /// Id of the tax rate preselected for new products.
  static const String defaultTaxRateId = 'default_tax_rate_id';

  /// `true` when new products default to tax-inclusive prices.
  static const String defaultPriceIncludesTax = 'default_price_includes_tax';

  /// Days between backup reminders (`0` = off).
  static const String backupReminderDays = 'backup_reminder_days';
}
