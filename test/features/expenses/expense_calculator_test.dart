import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/expenses/domain/services/expense_calculator.dart';
import 'package:inventrix/features/expenses/domain/services/expense_period.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  group('ExpenseCalculator', () {
    test('no tax: net and total equal the amount', () {
      final a = ExpenseCalculator.calculate(
        amount: inr(100000),
        includesTax: false,
        taxRateBp: 0,
      );
      expect(a.net, inr(100000));
      expect(a.tax, inr(0));
      expect(a.total, inr(100000));
    });

    test('tax-exclusive adds tax on top', () {
      final a = ExpenseCalculator.calculate(
        amount: inr(100000),
        includesTax: false,
        taxRateBp: 1800,
      );
      expect(a.net, inr(100000));
      expect(a.tax, inr(18000));
      expect(a.total, inr(118000));
    });

    test('tax-inclusive splits the amount', () {
      final a = ExpenseCalculator.calculate(
        amount: inr(118000),
        includesTax: true,
        taxRateBp: 1800,
      );
      expect(a.net, inr(100000));
      expect(a.tax, inr(18000));
      expect(a.total, inr(118000));
    });

    test('tax-inclusive rounding keeps net + tax == total', () {
      final a = ExpenseCalculator.calculate(
        amount: inr(10000),
        includesTax: true,
        taxRateBp: 1800,
      );
      expect(a.net, inr(8475));
      expect(a.tax, inr(1525));
      expect(a.net + a.tax, a.total);
    });

    test('tax rounds half away from zero', () {
      // 0.50 at 5% = 0.025 -> 0.03
      final a = ExpenseCalculator.calculate(
        amount: inr(50),
        includesTax: false,
        taxRateBp: 500,
      );
      expect(a.tax, inr(3));
      expect(a.total, inr(53));
    });

    test('tiny amount whose tax rounds to zero', () {
      final a = ExpenseCalculator.calculate(
        amount: inr(1),
        includesTax: false,
        taxRateBp: 1800,
      );
      expect(a.tax, inr(0));
      expect(a.total, inr(1));
    });

    test('large amounts stay exact', () {
      final a = ExpenseCalculator.calculate(
        amount: inr(999999999999),
        includesTax: false,
        taxRateBp: 1800,
      );
      expect(a.tax, inr(180000000000));
      expect(a.total, inr(1179999999999));
    });

    test('rejects a negative amount or rate', () {
      expect(
        () => ExpenseCalculator.calculate(
          amount: inr(-1),
          includesTax: false,
          taxRateBp: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExpenseCalculator.calculate(
          amount: inr(1),
          includesTax: false,
          taxRateBp: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ExpensePeriod', () {
    final today = DateTime.utc(2026, 3, 15);

    test('this month', () {
      final r = ExpensePeriod.thisMonth.rangeFor(today)!;
      expect(r.from, DateTime.utc(2026, 3, 1));
      expect(r.to, today);
    });

    test('last month, including across a year boundary', () {
      final r = ExpensePeriod.lastMonth.rangeFor(today)!;
      expect(r.from, DateTime.utc(2026, 2, 1));
      expect(r.to, DateTime.utc(2026, 2, 28));
      final jan = ExpensePeriod.lastMonth.rangeFor(DateTime.utc(2026, 1, 5))!;
      expect(jan.from, DateTime.utc(2025, 12, 1));
      expect(jan.to, DateTime.utc(2025, 12, 31));
    });

    test('last 30 days includes today', () {
      final r = ExpensePeriod.last30Days.rangeFor(today)!;
      expect(r.from, DateTime.utc(2026, 2, 14));
      expect(r.to, today);
    });

    test('this year and custom', () {
      expect(ExpensePeriod.thisYear.rangeFor(today)!.from, DateTime.utc(2026));
      expect(ExpensePeriod.custom.rangeFor(today), isNull);
    });
  });
}
