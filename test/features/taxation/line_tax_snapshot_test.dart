import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/taxation/domain/entities/line_tax_snapshot.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_calculator.dart';

import 'tax_test_fixtures.dart';

void main() {
  final cfg = config(
    rules: [rule('r')],
    components: [
      component('a', 'r', name: 'CGST', type: TaxComponentType.cgst, rate: 900, recoverable: true),
      component('b', 'r', name: 'SGST', type: TaxComponentType.sgst, rate: 900, order: 2),
    ],
  );
  final result = const TaxCalculator().calculate(cfg, input()).valueOrNull!;

  test('a snapshot freezes every figure of the calculation', () {
    final s = LineTaxSnapshot.fromResult(result);
    expect(s.regimeId, 'r1');
    expect(s.taxProfileId, kProfile);
    expect(s.taxCategoryId, kCategory);
    expect(s.treatment, 'standard_rated');
    expect(s.pricingMode, 'exclusive');
    expect(s.transactionDate, DateTime.utc(2026, 6, 1));
    expect(s.placeOfSupply, 'IN-KA');
    expect(s.ruleIds, ['r']);
    expect(s.components.map((c) => c.name), ['CGST', 'SGST']);
    expect(s.components.map((c) => c.amountMinor), [900, 900]);
    expect(s.components.first.taxableMinor, 10000);
    expect(s.components.first.isRecoverable, isTrue);
    expect(s.components.map((c) => c.order), [1, 2]);
  });

  test('encode then decode gives an equal snapshot', () {
    final s = LineTaxSnapshot.fromResult(result);
    expect(LineTaxSnapshot.decode(s.encode()), s);
  });

  test('the encoding is canonical: equal snapshots, identical text', () {
    final a = LineTaxSnapshot.fromResult(result).encode();
    final b = LineTaxSnapshot.fromResult(
      const TaxCalculator().calculate(cfg, input()).valueOrNull!,
    ).encode();
    expect(a, b);
    expect(a, startsWith('{"v":1,"regimeId":"r1"'));
  });

  test('a snapshot of an exempt line has no components', () {
    final exempt = config(categories: [category(kCategory, treatment: TaxTreatment.exempt)]);
    final r = const TaxCalculator().calculate(exempt, input()).valueOrNull!;
    final s = LineTaxSnapshot.decode(LineTaxSnapshot.fromResult(r).encode());
    expect(s.treatment, 'exempt');
    expect(s.components, isEmpty);
    expect(s.ruleIds, isEmpty);
  });

  test('a reverse-charge snapshot records the tax that was not charged', () {
    final rc = config(
      categories: [category(kCategory, treatment: TaxTreatment.reverseCharge)],
      rules: [rule('r')],
      components: [component('a', 'r', rate: 1000)],
    );
    final r = const TaxCalculator().calculate(rc, input()).valueOrNull!;
    expect(LineTaxSnapshot.fromResult(r).reverseChargeTaxMinor, 1000);
  });
}
