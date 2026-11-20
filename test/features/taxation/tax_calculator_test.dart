import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_calculator.dart';
import 'package:inventrix/shared/domain/services/line_calculator.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import 'tax_test_fixtures.dart';

void main() {
  const calculator = TaxCalculator();

  TaxCalculationResult ok(TaxConfiguration cfg, TaxCalculationInput i) {
    final result = calculator.calculate(cfg, i);
    expect(
      result.isSuccess,
      isTrue,
      reason: result.failureOrNull?.toString(),
    );
    return result.valueOrNull!;
  }

  // One 18% rule split into two components (intra) and one IGST (inter).
  final gstLike = config(
    rules: [
      rule('intra', relation: SupplyRelation.intra),
      rule('inter', relation: SupplyRelation.inter),
    ],
    components: [
      component('cg', 'intra', name: 'CGST', type: TaxComponentType.cgst, rate: 900),
      component('sg', 'intra', name: 'SGST', type: TaxComponentType.sgst, rate: 900, order: 2),
      component('ig', 'inter', name: 'IGST', type: TaxComponentType.igst, rate: 1800),
    ],
  );

  group('intra-state and inter-state', () {
    test('same state gives CGST + SGST and never IGST', () {
      final r = ok(gstLike, input());
      expect(r.components.map((c) => c.name), ['CGST', 'SGST']);
      expect(r.components.map((c) => c.amount), [inr(900), inr(900)]);
      expect(r.taxCharged, inr(1800));
      expect(r.totalAmount, inr(11800));
      expect(r.supplyRelation, SupplyRelation.intra);
    });

    test('different state gives IGST only', () {
      final r = ok(
        gstLike,
        input(place: const TaxLocation(countryCode: 'IN', regionCode: 'MH')),
      );
      expect(r.components.map((c) => c.name), ['IGST']);
      expect(r.taxCharged, inr(1800));
      expect(r.supplyRelation, SupplyRelation.inter);
    });

    test('India provider asks for the states instead of guessing', () {
      final result = calculator.calculate(
        gstLike,
        input(seller: const TaxLocation(countryCode: 'IN')),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('pricing modes', () {
    test('tax-exclusive adds tax on top', () {
      final r = ok(gstLike, input(gross: 30000));
      expect(r.taxableAmount, inr(30000));
      expect(r.totalAmount, inr(35400));
    });

    test('tax-inclusive extracts tax and keeps the entered price', () {
      final r = ok(gstLike, input(gross: 11800, pricing: PricingMode.inclusive));
      expect(r.taxableAmount, inr(10000));
      expect(r.taxCharged, inr(1800));
      expect(r.totalAmount, inr(11800));
    });

    test('inclusive component amounts always sum to total - net', () {
      for (final gross in [9999, 1, 7, 12345, 99991]) {
        final r = ok(
          gstLike,
          input(gross: gross, pricing: PricingMode.inclusive),
        );
        final sum = r.components.fold<int>(0, (s, c) => s + c.amount.minorUnits);
        expect(sum, r.taxCharged.minorUnits);
        expect(r.taxableAmount + r.taxCharged, inr(gross));
      }
    });

    test('a single component matches the existing LineCalculator', () {
      final single = config(
        rules: [rule('one')],
        components: [component('v', 'one', rate: 1800)],
      );
      for (final gross in [9999, 12345, 100, 1]) {
        final old = LineCalculator.calculate(
          unitPrice: inr(gross),
          quantity: Quantity.fromUnits(1),
          priceIncludesTax: true,
          discount: const Discount.none(),
          taxRateBp: 1800,
        ).valueOrNull!;
        final r = ok(single, input(gross: gross, pricing: PricingMode.inclusive));
        expect(r.taxableAmount, old.net);
        expect(r.taxCharged, old.tax);
      }
      final oldEx = LineCalculator.calculate(
        unitPrice: inr(9999),
        quantity: Quantity.fromUnits(1),
        priceIncludesTax: false,
        discount: const Discount.none(),
        taxRateBp: 1800,
      ).valueOrNull!;
      final r = ok(single, input(gross: 9999));
      expect(r.taxCharged, oldEx.tax);
      expect(r.totalAmount, oldEx.total);
    });

    test('a discount reduces the taxable amount', () {
      final r = ok(gstLike, input(gross: 10000, discount: 2000));
      expect(r.taxableAmount, inr(8000));
      expect(r.taxCharged, inr(1440));
      expect(r.discount, inr(2000));
    });
  });

  group('VAT, sales tax, compound and fixed', () {
    test('a single VAT component', () {
      final vat = config(
        rules: [rule('v')],
        components: [component('vat', 'v', name: 'VAT', type: TaxComponentType.vat, rate: 2000)],
      );
      final r = ok(vat, input(gross: 5000));
      expect(r.taxCharged, inr(1000));
      expect(r.components.single.type, TaxComponentType.vat);
    });

    test('stackable state and county sales taxes are both applied', () {
      final us = config(
        jurisdictions: const [
          TaxJurisdiction(id: 'st', regimeId: 'r1', countryCode: 'US', regionCode: 'TX', jurisdictionType: JurisdictionType.state),
          TaxJurisdiction(id: 'co', regimeId: 'r1', countryCode: 'US', regionCode: 'TX-A', jurisdictionType: JurisdictionType.county, parentJurisdictionId: 'st'),
        ],
        rules: [
          rule('state', jurisdictionId: 'st', stackable: true),
          rule('county', jurisdictionId: 'co', stackable: true),
        ],
        components: [
          component('s', 'state', name: 'State tax', type: TaxComponentType.salesTax, rate: 600),
          component('c', 'county', name: 'County tax', type: TaxComponentType.salesTax, rate: 100, order: 2),
        ],
      );
      const seller = TaxLocation(countryCode: 'US', regionCode: 'TX');
      final inCounty = ok(
        us,
        input(seller: seller, place: const TaxLocation(countryCode: 'US', regionCode: 'TX-A')),
      );
      expect(inCounty.taxCharged, inr(700));
      final stateOnly = ok(us, input(seller: seller, place: seller));
      expect(stateOnly.taxCharged, inr(600));
    });

    test('a compound component is taxed on base plus earlier tax', () {
      final compound = config(
        rules: [rule('r')],
        components: [
          component('a', 'r', rate: 500),
          component('b', 'r', rate: 1000, order: 2, compound: true),
        ],
      );
      final ex = ok(compound, input());
      expect(ex.components.map((c) => c.amount), [inr(500), inr(1050)]);
      expect(ex.taxCharged, inr(1550));
      final inc = ok(compound, input(gross: 11550, pricing: PricingMode.inclusive));
      expect(inc.taxableAmount, inr(10000));
      expect(inc.components.map((c) => c.amount), [inr(500), inr(1050)]);
    });

    test('a fixed per-unit tax multiplies by the quantity', () {
      final fixed = config(
        rules: [rule('f', method: TaxCalculationMethod.fixed)],
        components: [component('f1', 'f', fixed: 500)],
      );
      final ex = ok(fixed, input(gross: 30000, quantity: 3));
      expect(ex.taxCharged, inr(1500));
      expect(ex.components.single.fixedAmount, inr(500));
      final inc = ok(fixed, input(gross: 31500, quantity: 3, pricing: PricingMode.inclusive));
      expect(inc.taxableAmount, inr(30000));
    });

    test('a percentage rule and a fixed cess stack', () {
      final both = config(
        rules: [
          rule('pct', stackable: true),
          rule('cess', method: TaxCalculationMethod.fixed, stackable: true),
        ],
        components: [
          component('p', 'pct', rate: 1000),
          component('c', 'cess', fixed: 200, order: 2),
        ],
      );
      final r = ok(both, input(gross: 11200, pricing: PricingMode.inclusive));
      expect(r.taxableAmount, inr(10000));
      expect(r.taxCharged, inr(1200));
    });
  });

  group('rule resolution', () {
    test('no rule is a configuration failure, never zero tax', () {
      final r = calculator.calculate(config(), input());
      expect(r.failureOrNull, isA<TaxConfigurationFailure>());
    });

    test('an unknown category fails', () {
      final r = calculator.calculate(config(), input(categoryId: 'nope'));
      expect(r.failureOrNull, isA<TaxConfigurationFailure>());
    });

    test('equal rules conflict and are reported, not picked', () {
      final conflict = config(
        rules: [rule('a'), rule('b')],
        components: [component('ca', 'a', rate: 100), component('cb', 'b', rate: 200)],
      );
      final f = calculator.calculate(conflict, input()).failureOrNull;
      expect(f, isA<TaxRuleConflictFailure>());
      expect((f! as TaxRuleConflictFailure).ruleIds, ['a', 'b']);
    });

    test('priority breaks a tie', () {
      final c = config(
        rules: [rule('a'), rule('b', priority: 5)],
        components: [component('ca', 'a', rate: 100), component('cb', 'b', rate: 200)],
      );
      expect(ok(c, input()).ruleIds, ['b']);
    });

    test('a rule with more selectors beats a general one', () {
      final c = config(
        rules: [rule('general'), rule('goods', supplyType: 'goods')],
        components: [component('g', 'general', rate: 100), component('s', 'goods', rate: 200)],
      );
      expect(ok(c, input(supplyType: 'goods')).ruleIds, ['goods']);
      expect(ok(c, input(supplyType: 'services')).ruleIds, ['general']);
    });

    test('a deeper jurisdiction beats its parent at equal priority', () {
      final c = config(
        jurisdictions: const [
          TaxJurisdiction(id: 'country', regimeId: 'r1', countryCode: 'CA', jurisdictionType: JurisdictionType.country),
          TaxJurisdiction(id: 'prov', regimeId: 'r1', countryCode: 'CA', regionCode: 'ON', jurisdictionType: JurisdictionType.province, parentJurisdictionId: 'country'),
        ],
        rules: [
          rule('fed', jurisdictionId: 'country'),
          rule('on', jurisdictionId: 'prov'),
        ],
        components: [component('f', 'fed', rate: 500), component('o', 'on', rate: 1300)],
      );
      const on = TaxLocation(countryCode: 'CA', regionCode: 'ON');
      expect(ok(c, input(seller: on, place: on)).ruleIds, ['on']);
      const bc = TaxLocation(countryCode: 'CA');
      expect(ok(c, input(seller: bc, place: bc)).ruleIds, ['fed']);
    });

    test('a rule for another jurisdiction does not apply', () {
      final c = config(
        jurisdictions: const [
          TaxJurisdiction(id: 'ka', regimeId: 'r1', countryCode: 'IN', regionCode: 'KA', jurisdictionType: JurisdictionType.state),
        ],
        rules: [rule('ka-only', jurisdictionId: 'ka')],
        components: [component('k', 'ka-only', rate: 100)],
      );
      final r = calculator.calculate(
        c,
        input(place: const TaxLocation(countryCode: 'IN', regionCode: 'MH')),
      );
      expect(r.failureOrNull, isA<TaxConfigurationFailure>());
    });

    test('the same component applied by two rules is rejected', () {
      final c = config(
        rules: [rule('a', stackable: true), rule('b', stackable: true)],
        components: [
          component('x', 'a', name: 'VAT', type: TaxComponentType.vat, rate: 100),
          component('y', 'b', name: 'VAT', type: TaxComponentType.vat, rate: 100),
        ],
      );
      expect(
        calculator.calculate(c, input()).failureOrNull,
        isA<TaxRuleConflictFailure>(),
      );
    });

    test('inactive rules and components are ignored', () {
      final c = config(
        rules: [rule('a')],
        components: const [
          TaxComponent(id: 'x', taxRuleId: 'a', name: 'X', componentType: TaxComponentType.custom, calculationOrder: 1, rateBasisPoints: 100, isActive: false),
        ],
      );
      expect(calculator.calculate(c, input()).failureOrNull, isA<TaxConfigurationFailure>());
    });
  });

  group('effective dates', () {
    final dated = config(
      rules: [
        rule('old', until: DateTime.utc(2026, 3, 31)),
        rule('new', from: DateTime.utc(2026, 4, 1)),
      ],
      components: [component('o', 'old', rate: 1000), component('n', 'new', rate: 1200)],
    );

    test('the rule effective on the transaction date applies', () {
      expect(ok(dated, input(date: DateTime.utc(2026, 3, 31))).taxCharged, inr(1000));
      expect(ok(dated, input(date: DateTime.utc(2026, 4, 1))).taxCharged, inr(1200));
    });

    test('the time of day does not move a transaction across the boundary', () {
      final late = DateTime.utc(2026, 3, 31, 23, 59, 59);
      expect(ok(dated, input(date: late)).taxCharged, inr(1000));
    });

    test('a date before any rule fails', () {
      final r = calculator.calculate(dated, input(date: DateTime.utc(1999)));
      expect(r.failureOrNull, isA<TaxConfigurationFailure>());
    });
  });

  group('treatments', () {
    final zero = config(
      categories: [
        category(kCategory, treatment: TaxTreatment.zeroRated),
        category('ex', treatment: TaxTreatment.exempt),
        category('rc', treatment: TaxTreatment.reverseCharge),
      ],
      rules: [rule('rc-rule', categoryId: 'rc')],
      components: [component('rc1', 'rc-rule', rate: 1000)],
    );

    test('zero-rated has no tax and needs no rule', () {
      final r = ok(zero, input());
      expect(r.treatment, TaxTreatment.zeroRated);
      expect(r.taxCharged, inr(0));
      expect(r.totalAmount, inr(10000));
    });

    test('exempt has no tax and needs no rule', () {
      final r = ok(zero, input(categoryId: 'ex', pricing: PricingMode.inclusive));
      expect(r.treatment, TaxTreatment.exempt);
      expect(r.taxableAmount, inr(10000));
    });

    test('reverse charge computes tax but does not charge it', () {
      final r = ok(zero, input(categoryId: 'rc'));
      expect(r.reverseChargeTax, inr(1000));
      expect(r.taxCharged, inr(0));
      expect(r.totalAmount, inr(10000));
      expect(r.components, hasLength(1));
    });

    test('a transaction override forces a treatment and records why', () {
      final r = ok(
        gstLike,
        input(treatmentOverride: TaxTreatment.exempt, overrideReference: 'Certificate 42'),
      );
      expect(r.treatment, TaxTreatment.exempt);
      expect(r.taxCharged, inr(0));
      expect(r.treatmentReason, contains('Certificate 42'));
    });

    test('an unregistered seller charges no tax on a sale, but purchases still compute', () {
      final sale = ok(gstLike, input(sellerRegistered: false));
      expect(sale.treatment, TaxTreatment.outOfScope);
      expect(sale.taxCharged, inr(0));
      final purchase = ok(
        gstLike,
        input(type: TaxTransactionType.purchase, sellerRegistered: false),
      );
      expect(purchase.taxCharged, inr(1800));
    });

    test('recoverable components are reported separately', () {
      final c = config(
        rules: [rule('r')],
        components: [component('v', 'r', rate: 1000, recoverable: true)],
      );
      final r = ok(c, input(type: TaxTransactionType.purchase));
      expect(r.recoverableTax, inr(1000));
    });
  });

  group('validation', () {
    test('a discount larger than the amount is rejected', () {
      final r = calculator.calculate(gstLike, input(gross: 100, discount: 200));
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('inclusive fixed tax larger than the price is rejected', () {
      final fixed = config(
        rules: [rule('f', method: TaxCalculationMethod.fixed)],
        components: [component('f1', 'f', fixed: 5000)],
      );
      final r = calculator.calculate(fixed, input(gross: 1000, pricing: PricingMode.inclusive));
      expect(r.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('determinism and snapshots', () {
    test('the same input always gives the same result', () {
      final a = ok(gstLike, input(gross: 12345, pricing: PricingMode.inclusive));
      final b = ok(gstLike, input(gross: 12345, pricing: PricingMode.inclusive));
      expect(a.taxCharged, b.taxCharged);
      expect(a.components.map((c) => c.amount), b.components.map((c) => c.amount));
    });

    test('a calculated result does not change when the configuration does', () {
      final before = ok(gstLike, input());
      final changed = config(
        rules: [rule('intra', relation: SupplyRelation.intra)],
        components: [component('cg', 'intra', name: 'CGST', rate: 100)],
      );
      final after = ok(changed, input());
      expect(before.taxCharged, inr(1800));
      expect(after.taxCharged, inr(100));
      expect(before.components.first.rateBasisPoints, 900);
    });

    test('the result carries everything a snapshot needs', () {
      final r = ok(gstLike, input());
      expect(r.regimeId, 'r1');
      expect(r.taxCategoryId, kCategory);
      expect(r.ruleIds, ['intra']);
      expect(r.pricingMode, PricingMode.exclusive);
      expect(r.transactionDate, kJune2026);
      expect(r.components.first.ruleId, 'intra');
      expect(r.components.first.taxableAmount, inr(10000));
    });
  });

  test('breakdown groups components over several lines', () {
    final a = ok(gstLike, input(gross: 10000));
    final b = ok(gstLike, input(gross: 20000));
    final breakdown = TaxBreakdown.fromResults([a, b]);
    expect(breakdown.lines.map((l) => l.name), ['CGST', 'SGST']);
    expect(breakdown.lines.first.amount, inr(2700));
    expect(breakdown.lines.first.taxableAmount, inr(30000));
  });
}
