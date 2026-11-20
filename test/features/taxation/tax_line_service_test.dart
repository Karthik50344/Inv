import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_context.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';
import 'package:inventrix/features/taxation/domain/services/tax_line_service.dart';
import 'package:inventrix/shared/domain/services/line_calculator.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import 'tax_test_fixtures.dart';

class _Repo implements TaxRepository {
  _Repo(this.configuration, {this.context});
  TaxConfiguration configuration;
  TaxContext? context;

  @override
  Future<Result<TaxConfiguration>> loadConfiguration() async =>
      Result.success(configuration);

  @override
  Future<Result<TaxContext?>> loadContext() async => Result.success(context);
}

const _ctx = TaxContext(
  taxProfileId: kProfile,
  sellerLocation: TaxLocation(countryCode: 'IN', regionCode: 'KA'),
);

void main() {
  // What the 9 -> 10 migration produces for an 18% rate.
  final migrated = config(
    rules: [rule('r')],
    components: [component('c', 'r', name: 'GST 18%', rate: 1800)],
  );

  Future<Result<TaxedLine?>> run(
    TaxLineService service, {
    String? category = kCategory,
    String? override,
    int price = 10000,
    int qty = 1,
    bool inclusive = false,
    Discount discount = const Discount.none(),
  }) => service.calculate(
    productTaxCategoryId: category,
    productTaxOverrideId: override,
    type: TaxTransactionType.sale,
    date: kJune2026,
    unitPrice: inr(price),
    quantity: Quantity.fromUnits(qty),
    priceIncludesTax: inclusive,
    discount: discount,
  );

  test('a product with no category or override uses the legacy path', () async {
    final service = TaxLineService(repository: _Repo(migrated, context: _ctx));
    expect((await run(service, category: null)).valueOrNull, isNull);
  });

  test('no default tax profile means the legacy path', () async {
    final service = TaxLineService(repository: _Repo(migrated));
    final r = await run(service);
    expect(r.isSuccess, isTrue);
    expect(r.valueOrNull, isNull);
  });

  test('migrated single-rate configuration gives the old LineCalculator '
      'amounts', () async {
    final service = TaxLineService(repository: _Repo(migrated, context: _ctx));
    for (final inclusive in [false, true]) {
      for (final price in [1, 99, 9999, 12345, 100000]) {
        for (final discount in [
          const Discount.none(),
          Discount.percent(1000),
          Discount.amount(inr(50)),
        ]) {
          final old = LineCalculator.calculate(
            unitPrice: inr(price),
            quantity: Quantity.fromUnits(3),
            priceIncludesTax: inclusive,
            discount: discount,
            taxRateBp: 1800,
          ).valueOrNull;
          if (old == null) {
            continue; // fixed discount larger than the line
          }
          final taxed = (await run(
            service,
            price: price,
            qty: 3,
            inclusive: inclusive,
            discount: discount,
          )).valueOrNull!;
          expect(taxed.amounts, old, reason: '$price $inclusive $discount');
          expect(taxed.taxRateBp, 1800);
          expect(taxed.taxName, 'GST 18%');
        }
      }
    }
  });

  test('two components give a combined legacy rate and joined name', () async {
    final cfg = config(
      rules: [rule('r')],
      components: [
        component('a', 'r', name: 'CGST', rate: 900),
        component('b', 'r', name: 'SGST', rate: 900, order: 2),
      ],
    );
    final taxed = (await run(
      TaxLineService(repository: _Repo(cfg, context: _ctx)),
    )).valueOrNull!;
    expect(taxed.taxRateBp, 1800);
    expect(taxed.taxName, 'CGST + SGST');
    expect(taxed.amounts.tax, inr(1800));
    expect(taxed.snapshot.components, hasLength(2));
  });

  test('an exempt category has zero tax and keeps the category name', () async {
    final cfg = config(
      categories: [category(kCategory, treatment: TaxTreatment.exempt)],
    );
    final taxed = (await run(
      TaxLineService(repository: _Repo(cfg, context: _ctx)),
    )).valueOrNull!;
    expect(taxed.amounts.tax, inr(0));
    expect(taxed.taxName, 'Category c1');
    expect(taxed.snapshot.treatment, 'exempt');
  });

  test('an explicit override replaces the category', () async {
    final cfg = config(
      categories: [category(kCategory), category('ex', treatment: TaxTreatment.exempt)],
      rules: [rule('r')],
      components: [component('c', 'r', rate: 1800)],
      overrides: const [
        TaxOverride(id: 'o', name: 'Export', taxCategoryId: 'ex', reason: 'Export'),
      ],
    );
    final taxed = (await run(
      TaxLineService(repository: _Repo(cfg, context: _ctx)),
      override: 'o',
    )).valueOrNull!;
    expect(taxed.snapshot.taxCategoryId, 'ex');
    expect(taxed.amounts.tax, inr(0));
  });

  test('a configuration failure is returned, never zero tax', () async {
    final service = TaxLineService(repository: _Repo(config(), context: _ctx));
    expect((await run(service)).failureOrNull, isA<TaxConfigurationFailure>());
  });

  test('a discount larger than the line is a field error', () async {
    final service = TaxLineService(repository: _Repo(migrated, context: _ctx));
    final f = (await run(service, discount: Discount.amount(inr(999999)))).failureOrNull!;
    expect(f, isA<ValidationFailure>());
    expect((f as ValidationFailure).fieldErrors.keys, ['discount']);
  });
}
