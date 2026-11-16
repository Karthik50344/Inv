import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';

import 'data_test_support.dart';

void main() {
  late DataHarness h;

  setUp(() async {
    h = DataHarness();
    await h.units.create(unit());
    await h.categories.create(category());
  });
  tearDown(() => h.close());

  test('round-trips every field including money and quantity', () async {
    final original = product(
      barcode: 'BC-1234',
      categoryId: 'c1',
      sellingMinor: 12345,
    );
    expect((await h.products.create(original)).isSuccess, isTrue);
    final loaded = (await h.products.getById('p1')).valueOrNull!;
    expect(loaded, original);
    expect(loaded.sellingPrice.minorUnits, 12345);
    expect(loaded.sellingPrice.currencyCode, 'INR');
    expect(loaded.reorderLevel.milli, 5000);
  });

  test('creating a product also creates a zero inventory balance', () async {
    await h.products.create(product());
    final row = await h.db
        .customSelect(
          'SELECT quantity_on_hand_milli AS q, inventory_value_minor AS v '
          "FROM inventory_balances WHERE product_id = 'p1'",
        )
        .getSingle();
    expect(row.read<int>('q'), 0);
    expect(row.read<int>('v'), 0);
  });

  test('a failed create leaves neither product nor balance (atomic)', () async {
    await h.products.create(product());
    final dup = await h.products.create(product(id: 'p2'));
    expect(dup.failureOrNull, isA<DuplicateEntryFailure>());
    final products = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM products')
        .getSingle();
    final balances = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM inventory_balances')
        .getSingle();
    expect(products.read<int>('c'), 1);
    expect(balances.read<int>('c'), 1);
  });

  test('SKU and barcode lookups honour excludeId', () async {
    await h.products.create(product(barcode: 'BC-1234'));
    expect((await h.products.skuExists('SKU-1')).valueOrNull, isTrue);
    expect(
      (await h.products.skuExists('SKU-1', excludeId: 'p1')).valueOrNull,
      isFalse,
    );
    expect((await h.products.barcodeExists('BC-1234')).valueOrNull, isTrue);
    expect(
      (await h.products.barcodeExists('BC-1234', excludeId: 'p1')).valueOrNull,
      isFalse,
    );
    expect((await h.products.barcodeExists('NOPE-1')).valueOrNull, isFalse);
  });

  test('unique constraints back up the pre-checks', () async {
    await h.products.create(product(barcode: 'BC-1234'));
    final sku = await h.products.create(product(id: 'p2', barcode: 'BC-9999'));
    expect(sku.failureOrNull, isA<DuplicateEntryFailure>());
    final barcode = await h.products.create(
      product(id: 'p3', sku: 'S3', barcode: 'BC-1234'),
    );
    expect(barcode.failureOrNull, isA<DuplicateEntryFailure>());
    // Several products without a barcode are fine.
    expect(
      (await h.products.create(product(id: 'p4', sku: 'S4'))).isSuccess,
      isTrue,
    );
    expect(
      (await h.products.create(product(id: 'p5', sku: 'S5'))).isSuccess,
      isTrue,
    );
  });

  test('next auto SKU number ignores manual and malformed SKUs', () async {
    expect((await h.products.nextAutoSkuNumber()).valueOrNull, 1);
    await h.products.create(product(id: 'a', sku: 'P-000007'));
    await h.products.create(product(id: 'b', sku: 'P-12X'));
    await h.products.create(product(id: 'c', sku: 'HAMMER-9'));
    await h.products.create(product(id: 'd', sku: 'P-000003'));
    expect((await h.products.nextAutoSkuNumber()).valueOrNull, 8);
  });

  test('search by name, SKU and barcode; ordered by name', () async {
    await h.products.create(product(id: 'a', sku: 'A-1', name: 'Zed'));
    await h.products.create(
      product(id: 'b', sku: 'B-1', name: 'Alpha', barcode: 'BC-777'),
    );
    final all = (await h.products.search(const ProductFilter())).valueOrNull!;
    expect(all.map((p) => p.name).toList(), ['Alpha', 'Zed']);
    expect(
      (await h.products.search(const ProductFilter(query: 'alp')))
          .valueOrNull!
          .single
          .id,
      'b',
    );
    expect(
      (await h.products.search(const ProductFilter(query: 'a-1')))
          .valueOrNull!
          .single
          .id,
      'a',
    );
    expect(
      (await h.products.search(const ProductFilter(query: '777')))
          .valueOrNull!
          .single
          .id,
      'b',
    );
  });

  test('filters by category and archived state', () async {
    await h.products.create(product(id: 'a', sku: 'A', categoryId: 'c1'));
    await h.products.create(product(id: 'b', sku: 'B'));
    await h.products.create(product(id: 'c', sku: 'C', archived: t0));
    final byCategory = await h.products.search(
      const ProductFilter(categoryId: 'c1'),
    );
    expect(byCategory.valueOrNull!.single.id, 'a');
    final active = await h.products.search(const ProductFilter());
    expect(active.valueOrNull!.length, 2);
    final withArchived = await h.products.search(
      const ProductFilter(includeArchived: true),
    );
    expect(withArchived.valueOrNull!.length, 3);
  });

  test('update changes data; unknown ids are NotFound', () async {
    await h.products.create(product());
    final updated = product(name: 'Renamed', sellingMinor: 2000);
    expect((await h.products.update(updated)).isSuccess, isTrue);
    expect((await h.products.getById('p1')).valueOrNull?.name, 'Renamed');
    expect(
      (await h.products.update(product(id: 'ghost', sku: 'G'))).failureOrNull,
      isA<NotFoundFailure>(),
    );
    expect(
      (await h.products.getById('ghost')).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('archiving keeps the row and its history', () async {
    await h.products.create(product());
    await h.products.update(product().archived(t0));
    final loaded = (await h.products.getById('p1')).valueOrNull!;
    expect(loaded.isArchived, isTrue);
    expect(loaded.sku, 'SKU-1');
  });

  test('foreign keys reject unknown units and categories', () async {
    final badUnit = await h.products.create(product(unitId: 'ghost'));
    expect(badUnit.failureOrNull, isA<ValidationFailure>());
    final badCategory = await h.products.create(
      product(id: 'p2', sku: 'S2', categoryId: 'ghost'),
    );
    expect(badCategory.failureOrNull, isA<ValidationFailure>());
  });
}
