import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_config_validator.dart';

import 'tax_test_fixtures.dart';

void main() {
  final base = config(
    categories: [category(kCategory), category('ex', treatment: TaxTreatment.exempt)],
    rules: [rule('r1', from: DateTime.utc(2026), until: DateTime.utc(2026, 12, 31))],
    components: [component('c1', 'r1', name: 'VAT', type: TaxComponentType.vat, rate: 1000)],
    jurisdictions: const [
      TaxJurisdiction(id: 'in', regimeId: 'r1', countryCode: 'IN', jurisdictionType: JurisdictionType.country),
      TaxJurisdiction(id: 'ka', regimeId: 'r1', countryCode: 'IN', regionCode: 'KA', jurisdictionType: JurisdictionType.state, parentJurisdictionId: 'in'),
    ],
  );

  group('regime and jurisdiction', () {
    test('a good regime has no errors, bad codes are explained', () {
      expect(TaxConfigValidator.regime(const TaxRegime(id: 'r', name: 'GST', countryCode: 'IN', currencyCode: 'INR')), isEmpty);
      final e = TaxConfigValidator.regime(const TaxRegime(id: 'r', name: ' ', countryCode: 'india', currencyCode: 'rs'));
      expect(e.keys, containsAll(['name', 'countryCode', 'currencyCode']));
    });

    test('a place cannot be inside itself or inside its own child', () {
      TaxJurisdiction place(String id, String? parent) => TaxJurisdiction(
        id: id, regimeId: 'r1', countryCode: 'IN', jurisdictionType: JurisdictionType.state, parentJurisdictionId: parent,
      );
      expect(TaxConfigValidator.jurisdiction(place('ka', 'ka'), base)['parentJurisdictionId'], isNotNull);
      expect(TaxConfigValidator.jurisdiction(place('in', 'ka'), base)['parentJurisdictionId'], isNotNull);
      expect(TaxConfigValidator.jurisdiction(place('mh', 'in'), base), isEmpty);
    });

    test('an unknown tax system or parent is reported', () {
      const j = TaxJurisdiction(id: 'x', regimeId: 'nope', countryCode: 'IN', jurisdictionType: JurisdictionType.state, parentJurisdictionId: 'gone');
      expect(TaxConfigValidator.jurisdiction(j, base).keys, containsAll(['regimeId', 'parentJurisdictionId']));
    });
  });

  group('category, profile, override', () {
    test('a category code must be unique, ignoring case', () {
      final clash = TaxCategory(id: 'new', name: 'New', code: 'c1', defaultTaxTreatment: TaxTreatment.standardRated);
      expect(TaxConfigValidator.category(clash, base)['code'], contains('already'));
      expect(TaxConfigValidator.category(category('c9'), base), isEmpty);
      // Editing a category keeps its own code.
      expect(TaxConfigValidator.category(category(kCategory), base), isEmpty);
    });

    test('a profile needs an existing system and an active default category', () {
      const ok = TaxProfile(id: 'p', name: 'P', regimeId: 'r1', defaultTaxCategoryId: kCategory);
      expect(TaxConfigValidator.profile(ok, base), isEmpty);
      const bad = TaxProfile(id: 'p', name: 'P', regimeId: 'zzz', defaultTaxCategoryId: 'gone');
      expect(TaxConfigValidator.profile(bad, base).keys, containsAll(['regimeId', 'defaultTaxCategoryId']));
      const off = TaxProfile(id: 'p', name: 'P', regimeId: 'r1', isDefault: true, isActive: false);
      expect(TaxConfigValidator.profile(off, base)['isActive'], isNotNull);
    });

    test('an override must say why', () {
      expect(
        TaxConfigValidator.override(const TaxOverride(id: 'o', name: 'Export', taxCategoryId: 'ex', reason: ' '), base)['reason'],
        isNotNull,
      );
      expect(
        TaxConfigValidator.override(const TaxOverride(id: 'o', name: 'Export', taxCategoryId: 'ex', reason: 'Export certificate'), base),
        isEmpty,
      );
    });
  });

  group('rules', () {
    TaxRule candidate({String id = 'r2', DateTime? from, DateTime? until, int priority = 0, String? juris, bool stackable = false, String categoryId = kCategory}) => rule(
      id, from: from ?? DateTime.utc(2027), until: until, priority: priority, jurisdictionId: juris, stackable: stackable, categoryId: categoryId,
    );

    test('a rule that follows the existing one in time is fine', () {
      expect(TaxConfigValidator.rule(candidate(), base), isEmpty);
    });

    test('an identical situation with overlapping dates and the same priority is blocked', () {
      final e = TaxConfigValidator.rule(candidate(from: DateTime.utc(2026, 6, 1)), base);
      expect(e['priority'], contains('same priority'));
    });

    test('a different priority, a stackable rule or other dates are not ties', () {
      expect(TaxConfigValidator.rule(candidate(from: DateTime.utc(2026, 6), priority: 1), base), isEmpty);
      expect(TaxConfigValidator.rule(candidate(from: DateTime.utc(2026, 6), stackable: true), base), isEmpty);
      expect(TaxConfigValidator.rule(candidate(from: DateTime.utc(2025), until: DateTime.utc(2025, 12, 31)), base), isEmpty);
    });

    test('editing a rule does not tie it with itself', () {
      expect(TaxConfigValidator.rule(rule('r1', from: DateTime.utc(2026), until: DateTime.utc(2026, 12, 31)), base), isEmpty);
    });

    test('an open-ended rule overlaps every later one', () {
      final open = config(rules: [rule('a', from: DateTime.utc(2020))], components: [component('c', 'a', rate: 1)]);
      expect(TaxConfigValidator.rule(rule('b', from: DateTime.utc(2030)), open)['priority'], isNotNull);
    });

    test('end before start, odd priority, unknown place and exempt categories are refused', () {
      expect(TaxConfigValidator.rule(candidate(from: DateTime.utc(2027, 5), until: DateTime.utc(2027, 4)), base)['effectiveUntil'], isNotNull);
      expect(TaxConfigValidator.rule(candidate(priority: 5000), base)['priority'], isNotNull);
      expect(TaxConfigValidator.rule(candidate(juris: 'gone'), base)['jurisdictionId'], isNotNull);
      expect(TaxConfigValidator.rule(candidate(categoryId: 'ex'), base)['taxCategoryId'], contains('never charges tax'));
    });
  });

  group('components', () {
    test('percentage rule: rate from 0 to 1000 percent', () {
      expect(TaxConfigValidator.component(component('n', 'r1', name: 'CESS', rate: 100000), base), isEmpty);
      expect(TaxConfigValidator.component(component('n', 'r1', name: 'CESS', rate: 100001), base)['rateBasisPoints'], isNotNull);
      expect(TaxConfigValidator.component(component('n', 'r1', name: 'CESS', rate: -1), base)['rateBasisPoints'], isNotNull);
    });

    test('fixed rule: needs an amount and cannot be compound', () {
      final fixed = config(rules: [rule('f', method: TaxCalculationMethod.fixed)]);
      expect(TaxConfigValidator.component(component('n', 'f', name: 'Levy'), fixed)['fixedAmountMinor'], isNotNull);
      expect(TaxConfigValidator.component(component('n', 'f', name: 'Levy', fixed: 500, compound: true), fixed)['isCompound'], isNotNull);
      expect(TaxConfigValidator.component(component('n', 'f', name: 'Levy', fixed: 500), fixed), isEmpty);
    });

    test('a rule cannot hold two components with the same name and type', () {
      final dup = component('n', 'r1', name: 'vat', type: TaxComponentType.vat, rate: 500);
      expect(TaxConfigValidator.component(dup, base)['name'], contains('already'));
      expect(TaxConfigValidator.component(component('c1', 'r1', name: 'VAT', type: TaxComponentType.vat, rate: 1000), base), isEmpty);
    });

    test('type codes, order and rule are checked', () {
      final e = TaxConfigValidator.component(component('n', 'gone', name: 'X', type: const TaxComponentType('Bad Type'), order: 0), base);
      expect(e.keys, containsAll(['taxRuleId', 'componentType', 'calculationOrder']));
    });
  });

  test('the default profile and a default category cannot be switched off', () {
    final c = config(
      profile: const TaxProfile(id: kProfile, name: 'P', regimeId: 'r1', isDefault: true, defaultTaxCategoryId: kCategory),
    );
    expect(TaxConfigValidator.cannotDeactivate(c, 'tax_profile', kProfile), contains('default profile'));
    expect(TaxConfigValidator.cannotDeactivate(c, 'tax_category', kCategory), contains('default category'));
    expect(TaxConfigValidator.cannotDeactivate(c, 'tax_rule', 'x'), isNull);
  });
}
