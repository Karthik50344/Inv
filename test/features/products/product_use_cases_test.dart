import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/products/domain/usecases/update_product.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

import '../../support/domain_fixture.dart';

void main() {
  late DomainFixture f;
  late CreateProduct create;
  late UpdateProduct update;

  setUp(() {
    f = DomainFixture();
    seedUnit(f);
    create = CreateProduct(
      validator: f.validator,
      products: f.products,
      ids: f.ids,
      clock: f.clock,
    );
    update = UpdateProduct(
      validator: f.validator,
      products: f.products,
      clock: f.clock,
    );
  });

  ProductDraft draft({
    String name = 'Hammer',
    String sku = 'ham-1',
    String barcode = '',
    String unitId = 'u1',
    String? categoryId,
    String purchase = '',
    String selling = '',
    String reorder = '',
    String? taxRateId,
  }) => ProductDraft(
    name: name,
    sku: sku,
    barcode: barcode,
    unitId: unitId,
    categoryId: categoryId,
    purchasePrice: purchase,
    sellingPrice: selling,
    reorderLevel: reorder,
    taxRateId: taxRateId,
  );

  group('create', () {
    test('creates a product with typed money and quantity', () async {
      seedCategory(f);
      final r = await create(
        draft(
          categoryId: 'c1',
          purchase: '80.5',
          selling: '99.99',
          reorder: '5',
          barcode: 'ABC-1234',
        ),
      );
      final p = r.valueOrNull!;
      expect(p.sku, 'HAM-1');
      expect(p.purchasePrice.minorUnits, 8050);
      expect(p.sellingPrice.minorUnits, 9999);
      expect(p.sellingPrice.currencyCode, 'INR');
      expect(p.reorderLevel.milli, 5000);
      expect(p.barcode, 'ABC-1234');
      expect(f.products.items.length, 1);
    });

    test('blank prices and reorder level default to zero', () async {
      final p = (await create(draft())).valueOrNull!;
      expect(p.purchasePrice.isZero, isTrue);
      expect(p.sellingPrice.isZero, isTrue);
      expect(p.reorderLevel.isZero, isTrue);
    });

    test('generates sequential SKUs when blank', () async {
      final a = (await create(draft(sku: '', name: 'A'))).valueOrNull!;
      final b = (await create(draft(sku: ' ', name: 'B'))).valueOrNull!;
      expect(a.sku, 'P-000001');
      expect(b.sku, 'P-000002');
    });

    test('rejects invalid names and SKUs', () async {
      final r = await create(draft(name: ' ', sku: 'bad sku!'));
      expect(fieldErrorsOf(r).containsKey('name'), isTrue);
      expect(fieldErrorsOf(r).containsKey('sku'), isTrue);
      expect(f.products.items, isEmpty);
    });

    test('rejects duplicate SKU (case-insensitive) and barcode', () async {
      await create(draft(barcode: '1234'));
      final dupSku = await create(draft(sku: 'HAM-1', name: 'Other'));
      expect(fieldErrorsOf(dupSku).containsKey('sku'), isTrue);
      final dupBarcode = await create(
        draft(sku: 'X-1', name: 'Other', barcode: '1234'),
      );
      expect(fieldErrorsOf(dupBarcode).containsKey('barcode'), isTrue);
      expect(f.products.items.length, 1);
    });

    test('validates barcode format', () async {
      final r = await create(draft(barcode: 'a b'));
      expect(fieldErrorsOf(r).containsKey('barcode'), isTrue);
    });

    test('validates prices', () async {
      final r = await create(draft(purchase: 'abc', selling: '1.234'));
      expect(fieldErrorsOf(r).containsKey('purchasePrice'), isTrue);
      expect(fieldErrorsOf(r).containsKey('sellingPrice'), isTrue);
      final negative = await create(draft(selling: '-1'));
      expect(fieldErrorsOf(negative).containsKey('sellingPrice'), isTrue);
    });

    test('respects the configured currency decimals', () async {
      f.settings.config = const CurrencyConfig(
        currencyCode: 'JPY',
        decimalPlaces: 0,
      );
      final bad = await create(draft(selling: '10.5'));
      expect(fieldErrorsOf(bad).containsKey('sellingPrice'), isTrue);
      final ok = await create(draft(selling: '10'));
      expect(ok.valueOrNull?.sellingPrice.minorUnits, 10);
      expect(ok.valueOrNull?.sellingPrice.currencyCode, 'JPY');
    });

    test('reorder level must fit the unit precision', () async {
      final whole = await create(draft(reorder: '2.5'));
      expect(fieldErrorsOf(whole).containsKey('reorderLevel'), isTrue);
      seedUnit(f, id: 'kg', symbol: 'kg', decimals: 3);
      final fractional = await create(
        draft(unitId: 'kg', reorder: '2.5', sku: 'KG-1'),
      );
      expect(fractional.valueOrNull?.reorderLevel.milli, 2500);
      final negative = await create(draft(reorder: '-1', sku: 'N-1'));
      expect(fieldErrorsOf(negative).containsKey('reorderLevel'), isTrue);
    });

    test('requires an existing, active unit', () async {
      final none = await create(draft(unitId: ''));
      expect(fieldErrorsOf(none).containsKey('unitId'), isTrue);
      final missing = await create(draft(unitId: 'ghost'));
      expect(fieldErrorsOf(missing).containsKey('unitId'), isTrue);
      seedUnit(f, id: 'old', symbol: 'old', archived: true);
      final archived = await create(draft(unitId: 'old'));
      expect(fieldErrorsOf(archived).containsKey('unitId'), isTrue);
    });

    test('rejects missing or archived categories and tax rates', () async {
      final missing = await create(draft(categoryId: 'ghost'));
      expect(fieldErrorsOf(missing).containsKey('categoryId'), isTrue);
      seedCategory(f, id: 'old', name: 'Old', archived: true);
      final archived = await create(draft(categoryId: 'old'));
      expect(fieldErrorsOf(archived).containsKey('categoryId'), isTrue);
      final tax = await create(draft(taxRateId: 'ghost'));
      expect(fieldErrorsOf(tax).containsKey('taxRateId'), isTrue);
    });

    test('accepts an existing tax rate', () async {
      f.taxRates.items['t1'] = TaxRate(
        id: 't1',
        name: 'GST 18',
        rateBp: 1800,
        isExempt: false,
        createdAt: f.clock.now(),
        updatedAt: f.clock.now(),
      );
      final r = await create(draft(taxRateId: 't1'));
      expect(r.valueOrNull?.taxRateId, 't1');
    });
  });

  group('update', () {
    test('changes fields, keeps id and createdAt', () async {
      final created = (await create(draft(selling: '10'))).valueOrNull!;
      f.clock.advance(const Duration(days: 1));
      final r = await update(
        created.id,
        draft(name: 'Big hammer', selling: '12.5'),
      );
      final p = r.valueOrNull!;
      expect(p.id, created.id);
      expect(p.createdAt, created.createdAt);
      expect(p.updatedAt, f.clock.now());
      expect(p.name, 'Big hammer');
      expect(p.sellingPrice.minorUnits, 1250);
    });

    test('may keep its own SKU and barcode', () async {
      final created = (await create(draft(barcode: '9999'))).valueOrNull!;
      final r = await update(
        created.id,
        draft(barcode: '9999', name: 'Renamed'),
      );
      expect(r.isSuccess, isTrue);
    });

    test('cannot take another product SKU', () async {
      await create(draft(sku: 'A-1', name: 'A'));
      final b = (await create(draft(sku: 'B-1', name: 'B'))).valueOrNull!;
      final r = await update(b.id, draft(sku: 'a-1', name: 'B'));
      expect(fieldErrorsOf(r).containsKey('sku'), isTrue);
    });

    test('SKU cannot be blanked on update', () async {
      final p = (await create(draft())).valueOrNull!;
      final r = await update(p.id, draft(sku: ''));
      expect(fieldErrorsOf(r).containsKey('sku'), isTrue);
    });

    test('keeps an already-assigned archived category', () async {
      seedCategory(f);
      final p = (await create(draft(categoryId: 'c1'))).valueOrNull!;
      f.categories.items['c1'] = f.categories.items['c1']!.archived(
        f.clock.now(),
      );
      final r = await update(p.id, draft(categoryId: 'c1', name: 'Renamed'));
      expect(r.isSuccess, isTrue);
    });

    test('missing product is NotFound', () async {
      final r = await update('ghost', draft());
      expect(r.failureOrNull, isA<NotFoundFailure>());
    });

    test('does not rewrite history-bearing fields of other products', () async {
      final a = (await create(draft(sku: 'A-1', name: 'A', selling: '5')))
          .valueOrNull!;
      final b = (await create(draft(sku: 'B-1', name: 'B', selling: '7')))
          .valueOrNull!;
      await update(a.id, draft(sku: 'A-1', name: 'A2', selling: '6'));
      expect(f.products.items[b.id], b);
    });
  });

  group('archive, restore and search', () {
    test('archive and restore are idempotent', () async {
      final p = (await create(draft())).valueOrNull!;
      final archive = ArchiveProduct(products: f.products, clock: f.clock);
      final restore = RestoreProduct(products: f.products, clock: f.clock);
      expect((await archive(p.id)).isSuccess, isTrue);
      expect((await archive(p.id)).isSuccess, isTrue);
      expect(f.products.items[p.id]!.isArchived, isTrue);
      expect((await restore(p.id)).isSuccess, isTrue);
      expect((await restore(p.id)).isSuccess, isTrue);
      expect(f.products.items[p.id]!.isArchived, isFalse);
    });

    test('archive of a missing product is NotFound', () async {
      final r = await ArchiveProduct(products: f.products, clock: f.clock)('x');
      expect(r.failureOrNull, isA<NotFoundFailure>());
    });
  });
}
