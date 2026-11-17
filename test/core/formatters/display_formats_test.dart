import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/core/formatters/display_formats.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/core/formatters/number_grouping.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

Money money(int minor, {int places = 2, String code = 'INR'}) =>
    Money.fromMinor(minor, currencyCode: code, decimalPlaces: places);

void main() {
  tearDown(DisplayFormats.reset);

  group('groupDigits', () {
    test('groups by three', () {
      expect(groupDigits('0', separator: ',', indian: false), '0');
      expect(groupDigits('999', separator: ',', indian: false), '999');
      expect(groupDigits('1000', separator: ',', indian: false), '1,000');
      expect(
        groupDigits('1234567', separator: ',', indian: false),
        '1,234,567',
      );
      expect(groupDigits('123456', separator: '.', indian: false), '123.456');
    });

    test('groups lakh and crore style', () {
      expect(groupDigits('1000', separator: ',', indian: true), '1,000');
      expect(groupDigits('100000', separator: ',', indian: true), '1,00,000');
      expect(groupDigits('1234567', separator: ',', indian: true), '12,34,567');
      expect(
        groupDigits('900000000000000000', separator: ',', indian: true),
        '9,00,00,00,00,00,00,00,000',
      );
    });
  });

  group('MoneyFormatter styles', () {
    test('each number style', () {
      final amount = money(123456789);
      expect(
        const MoneyFormatter(style: NumberStyle.indian)
            .format(amount, withSymbol: false),
        '12,34,567.89',
      );
      expect(
        const MoneyFormatter(style: NumberStyle.international)
            .format(amount, withSymbol: false),
        '1,234,567.89',
      );
      expect(
        const MoneyFormatter(style: NumberStyle.european)
            .format(amount, withSymbol: false),
        '1.234.567,89',
      );
      expect(
        const MoneyFormatter(style: NumberStyle.spaced)
            .format(amount, withSymbol: false),
        '1 234 567,89',
      );
    });

    test('negative amounts and zero decimals', () {
      expect(
        const MoneyFormatter(style: NumberStyle.european)
            .format(money(-5), withSymbol: false),
        '-0,05',
      );
      expect(
        const MoneyFormatter(style: NumberStyle.international)
            .format(money(1234567, places: 0, code: 'JPY'), withSymbol: false),
        '1,234,567',
      );
      expect(
        const MoneyFormatter(style: NumberStyle.international)
            .format(money(1234567, places: 3, code: 'KWD'), withSymbol: false),
        '1,234.567',
      );
    });

    test('follows the style chosen in the settings', () {
      const formatter = MoneyFormatter();
      expect(
        formatter.format(money(123456789), withSymbol: false),
        '12,34,567.89',
      );
      DisplayFormats.apply(
        dateStyle: DateStyle.longMonth,
        numberStyle: NumberStyle.european,
      );
      expect(
        formatter.format(money(123456789), withSymbol: false),
        '1.234.567,89',
      );
    });

    test('a locale picks the matching style', () {
      expect(NumberStyle.fromLocale('en_IN'), NumberStyle.indian);
      expect(NumberStyle.fromLocale('en_US'), NumberStyle.international);
      expect(NumberStyle.fromLocale('de_DE'), NumberStyle.european);
      expect(NumberStyle.fromLocale('fr-FR'), NumberStyle.spaced);
    });
  });

  group('DateFormatter', () {
    final day = DateTime.utc(2026, 11, 5);

    test('each date style', () {
      expect(DateFormatter.date(day, style: DateStyle.longMonth), '5 Nov 2026');
      expect(
        DateFormatter.date(day, style: DateStyle.dayMonthYear),
        '05/11/2026',
      );
      expect(
        DateFormatter.date(day, style: DateStyle.monthDayYear),
        '11/05/2026',
      );
      expect(
        DateFormatter.date(day, style: DateStyle.yearMonthDay),
        '2026-11-05',
      );
    });

    test('follows the style chosen in the settings', () {
      expect(DateFormatter.date(day), '5 Nov 2026');
      DisplayFormats.apply(
        dateStyle: DateStyle.yearMonthDay,
        numberStyle: NumberStyle.indian,
      );
      expect(DateFormatter.date(day), '2026-11-05');
    });
  });

  group('stored names', () {
    test('parse falls back for missing or unknown text', () {
      expect(DateStyle.parse('yearMonthDay'), DateStyle.yearMonthDay);
      expect(DateStyle.parse('nope'), DateStyle.longMonth);
      expect(DateStyle.parse(null), DateStyle.longMonth);
      expect(NumberStyle.parse('spaced'), NumberStyle.spaced);
      expect(NumberStyle.parse(''), NumberStyle.indian);
      expect(ThemePreference.parse('dark'), ThemePreference.dark);
      expect(ThemePreference.parse('x'), ThemePreference.system);
    });
  });
}
