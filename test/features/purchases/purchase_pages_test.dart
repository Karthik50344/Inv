import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/save_purchase_draft.dart';
import 'package:inventrix/features/purchases/presentation/pages/purchase_detail_page.dart';
import 'package:inventrix/features/purchases/presentation/pages/purchase_form_page.dart';
import 'package:inventrix/features/purchases/presentation/pages/purchases_page.dart';
import 'package:inventrix/features/suppliers/domain/usecases/create_supplier.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

void main() {
  late TestWiring wiring;
  late String supplierId;
  late String productId;

  const base = '/more/purchases';

  setUp(() async {
    wiring = TestWiring();
    wiring.addUnit(id: 'u1');
    supplierId = (await wiring.locator<CreateSupplier>()(
      const PartyDraft(name: 'Asha Traders'),
    )).valueOrNull!.id;
    productId = (await wiring.locator<CreateProduct>()(
      const ProductDraft(name: 'Hammer', unitId: 'u1', purchasePrice: '10'),
    )).valueOrNull!.id;
  });

  Future<String> seedDraft({String qty = '3', String price = '10'}) async =>
      (await wiring.locator<SavePurchaseDraft>()(
        PurchaseDraftInput(
          supplierId: supplierId,
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [
            PurchaseLineInput(
              productId: productId,
              quantity: qty,
              unitPrice: price,
            ),
          ],
        ),
      )).valueOrNull!.id;

  testWidgets('shows an empty state', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    expect(find.byType(PurchasesPage), findsOneWidget);
    expect(find.text('No purchases yet'), findsOneWidget);
  });

  testWidgets('lists purchases and filters by status', (tester) async {
    final a = await seedDraft();
    final b = await seedDraft(qty: '1');
    (await wiring.locator<PostPurchase>()(b)).valueOrNull!;
    await pumpInventrix(tester, wiring, location: base);
    expect(find.byKey(Key('purchase_$a')), findsOneWidget);
    expect(find.byKey(Key('purchase_$b')), findsOneWidget);
    expect(find.textContaining('PUR-000001'), findsOneWidget);

    await tapKey(tester, 'filter_posted');
    expect(find.byKey(Key('purchase_$a')), findsNothing);
    expect(find.byKey(Key('purchase_$b')), findsOneWidget);
  });

  testWidgets('creates a draft through the form', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    await tapKey(tester, 'add_purchase');
    expect(find.byType(PurchaseFormPage), findsOneWidget);

    await tapKey(tester, 'purchase_supplier');
    await tester.tap(find.text('Asha Traders').last);
    await tester.pumpAndSettle();

    await tapKey(tester, 'add_line');
    await tapKey(tester, 'line_product');
    await tester.tap(find.textContaining('Hammer').last);
    await tester.pumpAndSettle();
    await enter(tester, 'line_quantity', '4');
    await enter(tester, 'line_price', '2.50');
    await tapKey(tester, 'save_line');
    expect(find.byKey(const Key('line_0')), findsOneWidget);
    expect(find.byKey(const Key('purchase_total')), findsOneWidget);

    await enter(tester, 'purchase_reference', 'INV-9');
    await tapKey(tester, 'save_purchase');
    expect(find.byType(PurchasesPage), findsOneWidget);
    final saved = wiring.purchases.items.values.single;
    expect(saved.status, DocumentStatus.draft);
    expect(saved.supplierReference, 'INV-9');
    expect(saved.totals.total.minorUnits, 1000);
    expect(wiring.inventory.ledger, isEmpty);
  });

  testWidgets('the form asks for a supplier and an item', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await tapKey(tester, 'save_purchase');
    expect(find.text('Choose a supplier.'), findsOneWidget);
    expect(find.byKey(const Key('lines_error')), findsOneWidget);
    expect(wiring.purchases.items, isEmpty);
  });

  testWidgets('the line sheet reports invalid quantities', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await tapKey(tester, 'add_line');
    await tapKey(tester, 'line_product');
    await tester.tap(find.textContaining('Hammer').last);
    await tester.pumpAndSettle();
    await enter(tester, 'line_quantity', '1.5');
    await tapKey(tester, 'save_line');
    expect(find.text('Enter a whole number.'), findsOneWidget);
    expect(find.byKey(const Key('line_0')), findsNothing);
  });

  testWidgets('detail shows lines and posts the purchase', (tester) async {
    final id = await seedDraft(qty: '3', price: '10');
    await pumpInventrix(tester, wiring, location: '$base/$id');
    expect(find.byType(PurchaseDetailPage), findsOneWidget);
    expect(find.byKey(const Key('detail_line_1')), findsOneWidget);
    expect(find.byKey(const Key('status_draft')), findsOneWidget);

    await tapKey(tester, 'post_purchase');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('status_posted')), findsOneWidget);
    expect(find.text('PUR-000001'), findsWidgets);
    final balance = (await wiring.inventory.getBalance(productId)).valueOrNull!;
    expect(balance.quantityOnHand, Quantity.fromUnits(3));
    expect(find.byKey(const Key('post_purchase')), findsNothing);
    expect(find.byKey(const Key('void_purchase')), findsOneWidget);
  });

  testWidgets('voiding needs a reason and reverses stock', (tester) async {
    final id = await seedDraft();
    (await wiring.locator<PostPurchase>()(id)).valueOrNull!;
    await pumpInventrix(tester, wiring, location: '$base/$id');
    await tapKey(tester, 'void_purchase');
    await enter(tester, 'void_reason_input', 'Entered twice');
    await tapKey(tester, 'confirm_void');
    expect(find.byKey(const Key('status_voided')), findsOneWidget);
    expect(find.text('Entered twice'), findsOneWidget);
    final balance = (await wiring.inventory.getBalance(productId)).valueOrNull!;
    expect(balance.quantityOnHand, Quantity.zero);
  });

  testWidgets('with approval on, the draft offers submit, not post', (
    tester,
  ) async {
    wiring.settings.purchaseApprovalRequired = true;
    final id = await seedDraft();
    await pumpInventrix(tester, wiring, location: '$base/$id');
    expect(find.byKey(const Key('post_purchase')), findsNothing);
    await tapKey(tester, 'submit_purchase');
    expect(find.byKey(const Key('status_pendingApproval')), findsOneWidget);
    await tapKey(tester, 'approve_purchase');
    expect(find.byKey(const Key('status_approved')), findsOneWidget);
    expect(find.byKey(const Key('post_purchase')), findsOneWidget);
  });

  testWidgets('cancelling a draft needs confirmation', (tester) async {
    final id = await seedDraft();
    await pumpInventrix(tester, wiring, location: '$base/$id');
    await tapKey(tester, 'cancel_purchase');
    await tester.tap(find.text('Cancel purchase').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('status_cancelled')), findsOneWidget);
    expect(wiring.inventory.ledger, isEmpty);
  });

  testWidgets('an unknown purchase id shows not found', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/missing');
    expect(find.text('Purchase not found'), findsOneWidget);
  });

  testWidgets('a posted purchase cannot be opened for editing', (tester) async {
    final id = await seedDraft();
    (await wiring.locator<PostPurchase>()(id)).valueOrNull!;
    await pumpInventrix(tester, wiring, location: '$base/$id/edit');
    expect(find.byKey(const Key('purchase_blocked')), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('save_purchase')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('the supplier screen shows what is owed', (tester) async {
    final id = await seedDraft(qty: '2', price: '50');
    (await wiring.locator<PostPurchase>()(id)).valueOrNull!;
    await pumpInventrix(
      tester,
      wiring,
      location: '/more/suppliers/$supplierId',
    );
    expect(find.byKey(const Key('party_balance')), findsOneWidget);
    expect(find.textContaining('100.00'), findsWidgets);
  });
}
