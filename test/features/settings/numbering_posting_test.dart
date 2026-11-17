import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';

import '../../support/domain_fixture.dart';
import '../../support/purchase_fakes.dart';

/// Posting uses the prefix and padding configured when the document is
/// posted; numbers already issued are never touched.
void main() {
  late PurchaseFixture f;

  setUp(() => f = PurchaseFixture());

  Future<String> postOne() async {
    final p = (await f.addProduct(name: 'Hammer', purchase: '10')).id;
    final draft = await f.draft([
      PurchaseLineInput(productId: p, quantity: '1', unitPrice: ''),
    ]);
    return (await f.post(draft.id)).valueOrNull!.number!;
  }

  test('default prefix and width', () async {
    expect(await postOne(), 'PUR-000001');
  });

  test('a changed prefix applies to the next posting only', () async {
    final first = await postOne();
    f.sequences.prefixes = {DocumentKind.purchaseInvoice: 'BILL-'};
    f.sequences.padding = 4;
    final second = await postOne();
    expect(first, 'PUR-000001');
    expect(second, 'BILL-0002');
  });

  test('the counter keeps running when the prefix changes back', () async {
    await postOne();
    f.sequences.prefixes = {DocumentKind.purchaseInvoice: 'BILL-'};
    await postOne();
    f.sequences.prefixes = {};
    expect(await postOne(), 'PUR-000003');
  });

  test('a rolled-back posting does not consume a number', () async {
    final p = (await f.addProduct(name: 'Hammer', purchase: '10')).id;
    final draft = await f.draft([
      PurchaseLineInput(productId: p, quantity: '1', unitPrice: ''),
    ]);
    f.audit.recordFailure = const DatabaseFailure('boom');
    expect((await f.post(draft.id)).isFailure, isTrue);
    f.audit.recordFailure = null;
    expect((await f.post(draft.id)).valueOrNull!.number, 'PUR-000001');
  });
}
