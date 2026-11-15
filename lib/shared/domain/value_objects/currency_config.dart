import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Active currency configuration used to build [Money] values.
final class CurrencyConfig extends Equatable {
  /// Creates a configuration.
  const CurrencyConfig({
    required this.currencyCode,
    required this.decimalPlaces,
  });

  /// Currency code, e.g. `INR`.
  final String currencyCode;

  /// Number of minor-unit digits.
  final int decimalPlaces;

  /// Zero amount in this currency.
  Money zero() =>
      Money.zero(currencyCode: currencyCode, decimalPlaces: decimalPlaces);

  /// Amount from minor units.
  Money fromMinor(int minorUnits) => Money.fromMinor(
    minorUnits,
    currencyCode: currencyCode,
    decimalPlaces: decimalPlaces,
  );

  /// Parses plain decimal text; `null` if invalid or over-precise.
  Money? parse(String text) => Money.tryParse(
    text,
    currencyCode: currencyCode,
    decimalPlaces: decimalPlaces,
  );

  @override
  List<Object?> get props => [currencyCode, decimalPlaces];
}
