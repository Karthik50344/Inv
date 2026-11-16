import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/add_common_units.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/archive_unit.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_unit.dart';
import 'package:inventrix/features/products/domain/usecases/restore_unit.dart';
import 'package:inventrix/features/products/domain/usecases/update_unit.dart';

import '../../support/domain_fixture.dart';

void main() {
  late DomainFixture f;
  late CreateUnit create;
  late UpdateUnit update;
  late ArchiveUnit archive;

  setUp(() {
    f = DomainFixture();
    create = CreateUnit(repository: f.units, ids: f.ids, clock: f.clock);
    update = UpdateUnit(repository: f.units, clock: f.clock);
    archive = ArchiveUnit(repository: f.units, clock: f.clock);
  });

  Future<void> addProductUsing(String unitId) async {
    await CreateProduct(
      validator: f.validator,
      products: f.products,
      ids: f.ids,
      clock: f.clock,
    )(ProductDraft(name: 'Item', unitId: unitId));
  }

  test('creates a unit', () async {
    final r = await create(
      name: ' Kilogram ',
      symbol: ' kg ',
      decimalPlaces: 3,
    );
    expect(r.valueOrNull?.name, 'Kilogram');
    expect(r.valueOrNull?.symbol, 'kg');
    expect(r.valueOrNull?.decimalPlaces, 3);
  });

  test('validates fields', () async {
    final r = await create(name: '', symbol: '', decimalPlaces: 4);
    final errors = fieldErrorsOf(r);
    expect(errors.containsKey('name'), isTrue);
    expect(errors.containsKey('symbol'), isTrue);
    expect(errors.containsKey('decimalPlaces'), isTrue);
    final negative = await create(name: 'x', symbol: 'x', decimalPlaces: -1);
    expect(fieldErrorsOf(negative).containsKey('decimalPlaces'), isTrue);
  });

  test('symbols are unique case-insensitively, archived included', () async {
    final kg = (await create(
      name: 'Kilogram',
      symbol: 'kg',
      decimalPlaces: 3,
    )).valueOrNull!;
    expect(
      fieldErrorsOf(await create(name: 'Other', symbol: 'KG', decimalPlaces: 0))
          .containsKey('symbol'),
      isTrue,
    );
    await archive(kg.id);
    expect(
      fieldErrorsOf(await create(name: 'Other', symbol: 'kg', decimalPlaces: 0))
          .containsKey('symbol'),
      isTrue,
    );
  });

  test(
    'precision may increase but not decrease once products use it',
    () async {
      final unit = (await create(
        name: 'Metre',
        symbol: 'm',
        decimalPlaces: 2,
      )).valueOrNull!;
      // Unused: free to reduce.
      final reduced = await update(
        id: unit.id,
        name: 'Metre',
        symbol: 'm',
        decimalPlaces: 1,
      );
      expect(reduced.isSuccess, isTrue);

      await addProductUsing(unit.id);
      final blocked = await update(
        id: unit.id,
        name: 'Metre',
        symbol: 'm',
        decimalPlaces: 0,
      );
      expect(fieldErrorsOf(blocked).containsKey('decimalPlaces'), isTrue);
      expect(f.units.items[unit.id]!.decimalPlaces, 1);

      final increased = await update(
        id: unit.id,
        name: 'Metre',
        symbol: 'm',
        decimalPlaces: 3,
      );
      expect(increased.valueOrNull?.decimalPlaces, 3);
    },
  );

  test('update rejects a symbol used by another unit', () async {
    await create(name: 'A', symbol: 'a', decimalPlaces: 0);
    final b = (await create(
      name: 'B',
      symbol: 'b',
      decimalPlaces: 0,
    )).valueOrNull!;
    final r = await update(id: b.id, name: 'B', symbol: 'A', decimalPlaces: 0);
    expect(fieldErrorsOf(r).containsKey('symbol'), isTrue);
  });

  test('archive is blocked while active products use the unit', () async {
    final unit = (await create(
      name: 'Piece',
      symbol: 'pcs',
      decimalPlaces: 0,
    )).valueOrNull!;
    await addProductUsing(unit.id);
    final blocked = await archive(unit.id);
    expect(blocked.failureOrNull, isA<ValidationFailure>());

    final productId = f.products.items.keys.single;
    await ArchiveProduct(products: f.products, clock: f.clock)(productId);
    expect((await archive(unit.id)).isSuccess, isTrue);
    expect(f.units.items[unit.id]!.isArchived, isTrue);
  });

  test('restore reactivates an archived unit', () async {
    final unit = (await create(
      name: 'Piece',
      symbol: 'pcs',
      decimalPlaces: 0,
    )).valueOrNull!;
    await archive(unit.id);
    expect(
      (await RestoreUnit(repository: f.units, clock: f.clock)(unit.id))
          .isSuccess,
      isTrue,
    );
    expect(f.units.items[unit.id]!.isArchived, isFalse);
  });

  test('AddCommonUnits is idempotent and skips existing symbols', () async {
    await create(name: 'Kilo', symbol: 'kg', decimalPlaces: 3);
    final add = AddCommonUnits(repository: f.units, createUnit: create);
    final first = await add();
    expect(first.valueOrNull, 7);
    final second = await add();
    expect(second.valueOrNull, 0);
    expect(f.units.items.length, 8);
  });
}
