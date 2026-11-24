/// Absolute route paths.
abstract final class RoutePaths {
  static const String intro = '/welcome';
  static const String setup = '/setup';
  static const String setupCompany = '/setup/company';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String inventory = '/inventory';
  static const String sales = '/sales';
  static const String more = '/more';
  static const String purchases = '/more/purchases';
  static const String customers = '/more/customers';
  static const String suppliers = '/more/suppliers';
  static const String payments = '/more/payments';
  static const String returns = '/more/returns';
  static const String expenses = '/more/expenses';
  static const String reports = '/more/reports';
  static const String backup = '/more/backup';
  static const String settings = '/more/settings';
  static const String taxSettings = '/more/tax';
  static const String taxSystems = '/more/tax/systems';
  static const String taxPlaces = '/more/tax/places';
  static const String taxProfiles = '/more/tax/profiles';
  static const String taxCategories = '/more/tax/categories';
  static const String taxOverrides = '/more/tax/overrides';
  static const String taxRules = '/more/tax/rules';
  static const String taxPreferences = '/more/tax/preferences';

  /// The details of tax rule [id].
  static String taxRule(String id) => '/more/tax/rules/$id';
  static const String audit = '/more/audit';
  static const String auditLog = '/more/audit/log';
  static const String auditIntegrity = '/more/audit/integrity';
  static const String auditExport = '/more/audit/export';
  static const String auditExports = '/more/audit/exports';

  /// The details of audit event [id].
  static String auditEvent(String id) => '/more/audit/event/$id';

  /// The details of export [id].
  static String auditExportDetail(String id) => '/more/audit/exports/$id';

  /// Returns [full] relative to [parent] (`/more/x` under `/more` -> `x`).
  static String relativeTo(String full, String parent) =>
      full.substring(parent.length + 1);
}
