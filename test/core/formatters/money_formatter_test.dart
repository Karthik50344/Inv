import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  const formatter = MoneyFormatter();

  test('uses Indian digit grouping by default', () {
    expect(formatter.format(inr(12345650), withSymbol: false), '1,23,456.50');
    expect(formatter.format(inr(0), withSymbol: false), '0.00');
    expect(formatter.format(inr(5), withSymbol: false), '0.05');
  });

  test('formats negative amounts with a leading minus', () {
    expect(formatter.format(inr(-12345), withSymbol: false), '-123.45');
    expect(formatter.format(inr(-5), withSymbol: false), '-0.05');
  });

  test('includes the currency symbol', () {
    expect(formatter.format(inr(100)), contains('₹'));
    expect(formatter.format(inr(100)), contains('1.00'));
  });

  test('handles zero-decimal currencies and large values exactly', () {
    final yen = Money.fromMinor(1234567, currencyCode: 'JPY', decimalPlaces: 0);
    expect(
      const MoneyFormatter(locale: 'en_US').format(yen, withSymbol: false),
      '1,234,567',
    );
    expect(
      formatter.format(inr(900000000000000001), withSymbol: false),
      '9,00,00,00,00,00,00,000.01',
    );
  });
}
