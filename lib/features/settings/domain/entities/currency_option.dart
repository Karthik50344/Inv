import 'package:equatable/equatable.dart';

/// A currency offered in the settings, with its usual number of decimals.
final class CurrencyOption extends Equatable {
  /// Creates an option.
  const CurrencyOption(this.code, this.name, this.decimalPlaces);

  /// ISO 4217 code.
  final String code;

  /// English name.
  final String name;

  /// Usual number of minor-unit digits.
  final int decimalPlaces;

  /// `INR - Indian rupee`.
  String get label => '$code - $name';

  @override
  List<Object?> get props => [code, name, decimalPlaces];
}

/// Currencies the settings screen suggests. Any other three-letter code can
/// be typed in; nothing in the app depends on this list.
abstract final class CurrencyCatalog {
  /// Suggested currencies.
  static const List<CurrencyOption> common = [
    CurrencyOption('INR', 'Indian rupee', 2),
    CurrencyOption('USD', 'US dollar', 2),
    CurrencyOption('EUR', 'Euro', 2),
    CurrencyOption('GBP', 'Pound sterling', 2),
    CurrencyOption('AED', 'UAE dirham', 2),
    CurrencyOption('SAR', 'Saudi riyal', 2),
    CurrencyOption('SGD', 'Singapore dollar', 2),
    CurrencyOption('MYR', 'Malaysian ringgit', 2),
    CurrencyOption('AUD', 'Australian dollar', 2),
    CurrencyOption('CAD', 'Canadian dollar', 2),
    CurrencyOption('LKR', 'Sri Lankan rupee', 2),
    CurrencyOption('BDT', 'Bangladeshi taka', 2),
    CurrencyOption('NPR', 'Nepalese rupee', 2),
    CurrencyOption('PKR', 'Pakistani rupee', 2),
    CurrencyOption('ZAR', 'South African rand', 2),
    CurrencyOption('KES', 'Kenyan shilling', 2),
    CurrencyOption('NGN', 'Nigerian naira', 2),
    CurrencyOption('CNY', 'Chinese yuan', 2),
    CurrencyOption('JPY', 'Japanese yen', 0),
    CurrencyOption('KRW', 'South Korean won', 0),
    CurrencyOption('KWD', 'Kuwaiti dinar', 3),
    CurrencyOption('BHD', 'Bahraini dinar', 3),
  ];

  /// The option for [code], or `null` for a currency that is not listed.
  static CurrencyOption? find(String code) {
    for (final option in common) {
      if (option.code == code) {
        return option;
      }
    }
    return null;
  }
}
