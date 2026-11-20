import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/products/domain/usecases/update_product.dart';

import '../../support/domain_fixture.dart';
import '../../support/inventory_fakes.dart';

/// Product changes are audited with before/after values, in the same
/// transaction as the change.
void main() {
  late DomainFixture f;
  late FakeAuditLogRepository audit;
  late FakeTransactionRunner tx;

  ProductDraft draft({String name = 'Hammer', String selling = '20', String taxRateId = ''}) =>
      ProductDraft(
        name: name,
        sku: 'H-1',
        unitId: 'u1',
        purchasePrice: '10',
        sellingPrice: selling,
        taxRateId: taxRateId.isEmpty ? null : taxRateId,
      );

  CreateProduct create() => CreateProduct(
    validator: f.validator,
    products: f.products,
    ids: f.ids,
    clock: f.clock,
    audit: audit,
    transactions: tx,
  );

  UpdateProduct update() => UpdateProduct(
    validator: f.validator,
    products: f.products,
    clock: f.clock,
    audit: audit,
    transactions: tx,
    ids: f.ids,
  );

  setUp(() {
    f = DomainFixture();
    seedUnit(f);
    audit = FakeAuditLogRepository();
    tx = FakeTransactionRunner([audit]);
  });

  test('creating a product records its values', () async {
    final product = (await create()(draft())).valueOrNull!;
    final e = audit.entries.single;
    expect(e.entityType, 'product');
    expect(e.entityId, product.id);
    expect(e.action, 'created');
    expect(e.newValues!['sku'], 'H-1');
    expect(e.newValues!['name'], 'Hammer');
    expect(e.previousValues, isNull);
  });

  test('updating records only the fields that changed', () async {
    final product = (await create()(draft())).valueOrNull!;
    audit.entries.clear();
    await update()(product.id, draft(selling: '25'));
    final e = audit.entries.single;
    expect(e.action, 'updated');
    expect(e.previousValues!.keys, ['sellingPriceMinor']);
    expect(e.newValues!.keys, ['sellingPriceMinor']);
    expect(e.previousValues!['sellingPriceMinor'], isNot(e.newValues!['sellingPriceMinor']));
  });

  test('saving without any change records nothing', () async {
    final product = (await create()(draft())).valueOrNull!;
    audit.entries.clear();
    await update()(product.id, draft());
    expect(audit.entries, isEmpty);
  });

  test('archive and restore are recorded', () async {
    final product = (await create()(draft())).valueOrNull!;
    audit.entries.clear();
    await ArchiveProduct(products: f.products, clock: f.clock, audit: audit, transactions: tx, ids: f.ids)(product.id);
    await RestoreProduct(products: f.products, clock: f.clock, audit: audit, transactions: tx, ids: f.ids)(product.id);
    expect(audit.entries.map((e) => e.action), ['archived', 'restored']);
    expect(audit.entries.first.newValues, {'archived': true});
    expect(audit.entries.last.previousValues, {'archived': true});
  });

  test('archiving an already archived product records nothing more', () async {
    final product = (await create()(draft())).valueOrNull!;
    final archive = ArchiveProduct(products: f.products, clock: f.clock, audit: audit, transactions: tx, ids: f.ids);
    await archive(product.id);
    audit.entries.clear();
    await archive(product.id);
    expect(audit.entries, isEmpty);
  });

  test('if the audit cannot be written the operation fails', () async {
    audit.recordFailure = const AuditFailure('audit unavailable');
    final r = await create()(draft());
    // The failure is returned to the caller (the real runner rolls the
    // product back; see the database-level rollback test).
    expect(r.failureOrNull, isA<AuditFailure>());
  });

  test('without audit dependencies the use cases behave as before', () async {
    final plain = CreateProduct(
      validator: f.validator,
      products: f.products,
      ids: f.ids,
      clock: f.clock,
    );
    expect((await plain(draft())).isSuccess, isTrue);
    expect(audit.entries, isEmpty);
  });
}
