import 'package:intl/intl.dart';
import 'package:inventrix/core/formatters/display_formats.dart';
import 'package:inventrix/core/formatters/number_grouping.dart';
import 'package:inventrix/core/utils/rounding.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Display formatting for [Money] (never used for arithmetic).
///
/// Digits are grouped and separated according to a [NumberStyle] and the
/// fraction is taken straight from the integer minor units, so no floating
/// point is involved. Without arguments the style chosen in the settings
/// (`DisplayFormats`) is used; passing [locale] (for example `en_US`) picks
/// the matching style instead.
class MoneyFormatter {
  /// Creates a formatter. [style] wins over [locale]; with neither, the
  /// style chosen in the settings is used each time something is formatted.
  const MoneyFormatter({this.locale, this.style});

  /// Locale that selects the style (`en_IN` gives lakh/crore grouping).
  final String? locale;

  /// Explicit style.
  final NumberStyle? style;

  NumberStyle get _style =>
      style ??
      (locale == null
          ? DisplayFormats.numberStyle
          : NumberStyle.fromLocale(locale!));

  /// Formats [money], e.g. `₹ 1,23,456.50`. Set [withSymbol] to false
  /// for a bare number.
  String format(Money money, {bool withSymbol = true}) {
    final style = _style;
    final factor = pow10(money.decimalPlaces);
    final minor = money.minorUnits;
    final whole = (minor ~/ factor).abs();
    final fraction = minor.abs() % factor;
    final grouped = groupDigits(
      whole.toString(),
      separator: style.group,
      indian: style.indianGrouping,
    );
    final digits = money.decimalPlaces == 0
        ? grouped
        : '$grouped${style.decimal}'
              '${fraction.toString().padLeft(money.decimalPlaces, '0')}';
    final signed = minor < 0 ? '-$digits' : digits;
    if (!withSymbol) {
      return signed;
    }
    final symbol = NumberFormat.currency(
      locale: locale ?? style.symbolLocale,
      name: money.currencyCode,
    ).currencySymbol;
    return minor < 0 ? '-$symbol $digits' : '$symbol $digits';
  }
}
