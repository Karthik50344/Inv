import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

/// The date and number styles the user picked in the settings.
///
/// Formatting helpers (`MoneyFormatter`, `DateFormatter`) read the current
/// styles when they format, so a widget that is rebuilt after a change shows
/// the new style without being handed anything. This is display state only:
/// it never affects stored values or calculations.
abstract final class DisplayFormats {
  static DateStyle _dateStyle = DateStyle.longMonth;
  static NumberStyle _numberStyle = NumberStyle.indian;

  /// Style used for dates.
  static DateStyle get dateStyle => _dateStyle;

  /// Style used for numbers and money.
  static NumberStyle get numberStyle => _numberStyle;

  /// Makes [dateStyle] and [numberStyle] the active styles.
  static void apply({
    required DateStyle dateStyle,
    required NumberStyle numberStyle,
  }) {
    _dateStyle = dateStyle;
    _numberStyle = numberStyle;
  }

  /// Back to the defaults (used by tests and after a restore).
  static void reset() =>
      apply(dateStyle: DateStyle.longMonth, numberStyle: NumberStyle.indian);
}
