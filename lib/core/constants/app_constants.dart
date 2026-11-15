/// Application-wide constants.
abstract final class AppConstants {
  /// Name shown throughout the UI and in branding.
  static const String appName = 'Inventrix';

  /// SQLite file base name; `drift_flutter` appends `.sqlite`.
  static const String databaseName = 'inventory_management';

  /// Default currency used until the user changes it in settings.
  static const String defaultCurrencyCode = 'INR';

  /// Default number of currency decimal places.
  static const int defaultCurrencyDecimalPlaces = 2;

  /// Default locale used for number and date formatting.
  static const String defaultLocale = 'en_IN';

  /// Warning shown on the dashboard and backup screens.
  static const String localDataWarning =
      'Your business data is stored locally on this device. Uninstalling the '
      'app or clearing its data may permanently delete your information. '
      'Export a backup to a safe external location regularly.';
}
