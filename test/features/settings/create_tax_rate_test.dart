import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/usecases/create_tax_rate.dart';

import '../../support/domain_fixture.dart';
import '../../support/fakes.dart';

void main() {
  late FakeTaxRateRepository repo;
  late CreateTaxRate createTaxRate;

  setUp(() {
    repo = FakeTaxRateRepository();
    createTaxRate = CreateTaxRate(
      repository: repo,
      ids: SequentialIds(),
      clock: FakeClock(),
    );
  });

  test('stores percentages as basis points', () async {
    final a = await createTaxRate(name: 'GST 18', ratePercent: '18');
    final b = await createTaxRate(name: 'GST 12.5', ratePercent: '12.5');
    expect(a.valueOrNull?.rateBp, 1800);
    expect(b.valueOrNull?.rateBp, 1250);
    expect(repo.items.length, 2);
  });

  test('exempt rates ignore the percentage and are zero', () async {
    final r = await createTaxRate(
      name: 'Exempt',
      ratePercent: '',
      isExempt: true,
    );
    expect(r.valueOrNull?.rateBp, 0);
    expect(r.valueOrNull?.isExempt, isTrue);
  });

  test('rejects invalid names and rates', () async {
    final r = await createTaxRate(name: ' ', ratePercent: 'abc');
    expect(fieldErrorsOf(r).containsKey('name'), isTrue);
    expect(fieldErrorsOf(r).containsKey('ratePercent'), isTrue);
    final tooHigh = await createTaxRate(name: 'X', ratePercent: '1000.01');
    expect(fieldErrorsOf(tooHigh).containsKey('ratePercent'), isTrue);
    final tooPrecise = await createTaxRate(name: 'X', ratePercent: '1.234');
    expect(fieldErrorsOf(tooPrecise).containsKey('ratePercent'), isTrue);
  });

  test('rejects duplicate names case-insensitively', () async {
    await createTaxRate(name: 'GST', ratePercent: '5');
    final r = await createTaxRate(name: 'gst', ratePercent: '5');
    expect(fieldErrorsOf(r).containsKey('name'), isTrue);
    expect(repo.items.length, 1);
  });

  test('percentLabel formats basis points', () {
    TaxRate rate(int bp) => TaxRate(
      id: 'x',
      name: 'x',
      rateBp: bp,
      isExempt: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    expect(rate(1800).percentLabel, '18');
    expect(rate(1250).percentLabel, '12.5');
    expect(rate(5).percentLabel, '0.05');
    expect(rate(0).percentLabel, '0');
  });
}
