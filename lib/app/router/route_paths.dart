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

  /// Returns [full] relative to [parent] (`/more/x` under `/more` -> `x`).
  static String relativeTo(String full, String parent) =>
      full.substring(parent.length + 1);
}
