import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/product_classification/data/repositories/drift_product_classification_repository.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';

import '../core/database/database_test_helpers.dart';

/// Against the real schema (in-memory SQLite). Written without a Flutter SDK:
/// not yet executed.
void main() {
  late AppDatabase db;
  late DriftProductClassificationRepository repo;

  ProductClassification make(
    String id, {
    String product = 'p1',
    String system = 'hsn',
    String code = '8471',
    bool primary = false,
    int minute = 0,
    String? description,
  }) => ProductClassification(
    id: id,
    productId: product,
    system: ClassificationSystem(system),
    code: code,
    description: description,
    type: ClassificationType.goods,
    isPrimary: primary,
    createdAt: DateTime.utc(2026, 6, 1, 10, minute),
    updatedAt: DateTime.utc(2026, 6, 1, 10, minute),
  );

  Future<List<ProductClassification>> list([String product = 'p1']) async =>
      (await repo.listForProduct(product)).valueOrNull!;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    repo = DriftProductClassificationRepository(db);
    await insertUnit(db, 'u1');
    await insertProduct(db, 'p1', sku: 'A');
    await insertProduct(db, 'p2', sku: 'B');
  });

  tearDown(() => db.close());

  test('the first classification becomes primary', () async {
    await repo.add(make('c1'));
    expect((await list()).single.isPrimary, isTrue);
  });

  test('a later one is not primary unless asked', () async {
    await repo.add(make('c1'));
    await repo.add(make('c2', code: '8472', minute: 1));
    final all = await list();
    expect(all.map((c) => c.id), ['c1', 'c2']);
    expect(all.map((c) => c.isPrimary), [true, false]);
  });

  test('adding a new primary demotes the old one', () async {
    await repo.add(make('c1'));
    await repo.add(make('c2', code: '8472', primary: true, minute: 1));
    final all = await list();
    expect(all.firstWhere((c) => c.id == 'c2').isPrimary, isTrue);
    expect(all.where((c) => c.isPrimary), hasLength(1));
  });

  test('setPrimary moves the flag and keeps exactly one primary', () async {
    await repo.add(make('c1'));
    await repo.add(make('c2', code: '8472', minute: 1));
    await repo.setPrimary('p1', 'c2');
    expect((await repo.primaryFor('p1')).valueOrNull!.id, 'c2');
    expect((await list()).where((c) => c.isPrimary), hasLength(1));
  });

  test('removing the primary promotes the oldest remaining', () async {
    await repo.add(make('c1'));
    await repo.add(make('c2', code: '8472', minute: 1));
    await repo.add(make('c3', code: '8473', minute: 2));
    await repo.remove('c1');
    expect((await repo.primaryFor('p1')).valueOrNull!.id, 'c2');
    await repo.remove('c2');
    await repo.remove('c3');
    expect(await list(), isEmpty);
    expect((await repo.primaryFor('p1')).valueOrNull, isNull);
  });

  test('the same system and code twice on one product is a duplicate', () async {
    await repo.add(make('c1'));
    final again = await repo.add(make('c2'));
    expect(again.failureOrNull, isA<DuplicateEntryFailure>());
    // Another product may use the same code.
    expect((await repo.add(make('c3', product: 'p2'))).isSuccess, isTrue);
  });

  test('update keeps the primary flag', () async {
    await repo.add(make('c1'));
    await repo.update(make('c1', code: '8473', description: 'Laptops', primary: false));
    final c = (await list()).single;
    expect(c.code, '8473');
    expect(c.description, 'Laptops');
    expect(c.isPrimary, isTrue);
  });

  test('updating a missing classification fails', () async {
    expect((await repo.update(make('nope'))).failureOrNull, isA<NotFoundFailure>());
  });

  test('the database refuses a second primary', () async {
    await repo.add(make('c1'));
    await repo.add(make('c2', code: '8472', minute: 1));
    await expectLater(
      db.customStatement("UPDATE product_classifications SET is_primary = 1 WHERE id = 'c2'"),
      throwsA(anything),
    );
  });

  test('search finds codes already in use, most used first', () async {
    await repo.add(make('c1', description: 'Computers'));
    await repo.add(make('c2', product: 'p2', description: 'Computers'));
    await repo.add(make('c3', code: '9983', system: 'sac', minute: 1));
    final byCode = (await repo.search('84')).valueOrNull!;
    expect(byCode.single.code, '8471');
    expect(byCode.single.productCount, 2);
    final byText = (await repo.search('comput')).valueOrNull!;
    expect(byText.single.code, '8471');
    final all = (await repo.search('')).valueOrNull!;
    expect(all.map((s) => s.code), ['8471', '9983']);
    expect((await repo.search('zzz')).valueOrNull, isEmpty);
  });

  test('search treats % and _ literally', () async {
    await repo.add(make('c1'));
    expect((await repo.search('%')).valueOrNull, isEmpty);
    expect((await repo.search('_')).valueOrNull, isEmpty);
  });
}
