import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/utils/rounding.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:intl/intl.dart';

/// Locale-aware display formatting for [Money] (never used for arithmetic).
///
/// Digits are grouped by the locale (`en_IN` gives lakh/crore grouping) and
/// the fraction is taken straight from the integer minor units, so no
/// floating point is involved.
class MoneyFormatter {
  /// Creates a formatter for [locale].
  const MoneyFormatter({this.locale = AppConstants.defaultLocale});

  /// Locale used for grouping and the currency symbol.
  final String locale;

  /// Formats [money], e.g. `₹ 1,23,456.50`. Set [withSymbol] to false for a
  /// bare number.
  String format(Money money, {bool withSymbol = true}) {
    final factor = pow10(money.decimalPlaces);
    final minor = money.minorUnits;
    final whole = (minor ~/ factor).abs();
    final fraction = minor.abs() % factor;
    final grouped = NumberFormat.decimalPattern(locale).format(whole);
    // .format(BigInt.from(whole));
    final digits = money.decimalPlaces == 0
        ? grouped
        : '$grouped.${fraction.toString().padLeft(money.decimalPlaces, '0')}';
    final signed = minor < 0 ? '-$digits' : digits;
    if (!withSymbol) {
      return signed;
    }
    final symbol = NumberFormat.currency(
      locale: locale,
      name: money.currencyCode,
    ).currencySymbol;
    return minor < 0 ? '-$symbol $digits' : '$symbol $digits';
  }
}
