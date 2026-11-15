import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/usecases/post_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/save_sales_draft.dart';
import 'package:inventrix/features/sales/presentation/pages/sales_detail_page.dart';
import 'package:inventrix/features/sales/presentation/pages/sales_form_page.dart';
import 'package:inventrix/features/sales/presentation/pages/sales_page.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

void main() {
  late TestWiring wiring;
  late String customerId;
  late String productId;

  const base = '/sales';

  setUp(() async {
    wiring = TestWiring();
    wiring.addUnit(id: 'u1');
    customerId = (await wiring.locator<CreateCustomer>()(
      const PartyDraft(name: 'Asha Traders'),
    )).valueOrNull!.id;
    productId = (await wiring.locator<CreateProduct>()(
      const ProductDraft(name: 'Hammer', unitId: 'u1', sellingPrice: '10'),
    )).valueOrNull!.id;
    final stocked = await wiring.locator<AdjustStock>()(
      productId: productId,
      direction: StockAdjustmentDirection.stockIn,
      quantity: '50',
      reason: 'test stock',
      unitCost: '4',
    );
    expect(stocked.isSuccess, isTrue);
  });

  Future<String> seedDraft({String qty = '3', String price = '10'}) async =>
      (await wiring.locator<SaveSalesDraft>()(
        SalesDraftInput(
          customerId: customerId,
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [
            SalesLineInput(
              productId: productId,
              quantity: qty,
              unitPrice: price,
            ),
          ],
        ),
      )).valueOrNull!.id;

  testWidgets('shows an empty state', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    expect(find.byType(SalesPage), findsOneWidget);
    expect(find.text('No sales yet'), findsOneWidget);
  });

  testWidgets('lists sales and filters by status', (tester) async {
    final a = await seedDraft();
    final b = await seedDraft(qty: '1');
    (await wiring.locator<PostSale>()(b)).valueOrNull!;
    await pumpInventrix(tester, wiring, location: base);
    expect(find.byKey(Key('sales_$a')), findsOneWidget);
    expect(find.byKey(Key('sales_$b')), findsOneWidget);
    expect(find.textContaining('INV-000001'), findsOneWidget);

    await tapKey(tester, 'filter_posted');
    expect(find.byKey(Key('sales_$a')), findsNothing);
    expect(find.byKey(Key('sales_$b')), findsOneWidget);
  });

  testWidgets('creates a draft through the form', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    await tapKey(tester, 'add_sale');
    expect(find.byType(SalesFormPage), findsOneWidget);

    await tapKey(tester, 'sales_customer');
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
    expect(find.byKey(const Key('sales_total')), findsOneWidget);

    await enter(tester, 'sales_reference', 'INV-9');
    await tapKey(tester, 'save_sale');
    expect(find.byType(SalesPage), findsOneWidget);
    final saved = wiring.salesInvoices.items.values.single;
    expect(saved.status, DocumentStatus.draft);
    expect(saved.customerReference, 'INV-9');
    expect(saved.totals.total.minorUnits, 1000);
    expect(wiring.inventory.ledger.length, 1); // only the test stock
  });

  testWidgets('the form asks for at least one item', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await tapKey(tester, 'save_sale');
    expect(find.byKey(const Key('lines_error')), findsOneWidget);
    expect(wiring.salesInvoices.items, isEmpty);
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

  testWidgets('detail shows lines and posts the sale', (tester) async {
    final id = await seedDraft(qty: '3', price: '10');
    await pumpInventrix(tester, wiring, location: '$base/$id');
    expect(find.byType(SalesDetailPage), findsOneWidget);
    expect(find.byKey(const Key('detail_line_1')), findsOneWidget);
    expect(find.byKey(const Key('status_draft')), findsOneWidget);

    await tapKey(tester, 'post_sale');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('status_posted')), findsOneWidget);
    expect(find.text('INV-000001'), findsWidgets);
    final balance = (await wiring.inventory.getBalance(productId)).valueOrNull!;
    expect(balance.quantityOnHand, Quantity.fromUnits(47));
    expect(find.byKey(const Key('post_sale')), findsNothing);
    expect(find.byKey(const Key('void_sale')), findsOneWidget);
  });

  testWidgets('voiding needs a reason and puts stock back', (tester) async {
    final id = await seedDraft();
    (await wiring.locator<PostSale>()(id)).valueOrNull!;
    await pumpInventrix(tester, wiring, location: '$base/$id');
    await tapKey(tester, 'void_sale');
    await enter(tester, 'void_reason_input', 'Entered twice');
    await tapKey(tester, 'confirm_void');
    expect(find.byKey(const Key('status_voided')), findsOneWidget);
    expect(find.text('Entered twice'), findsOneWidget);
    final balance = (await wiring.inventory.getBalance(productId)).valueOrNull!;
    expect(balance.quantityOnHand, Quantity.fromUnits(50));
  });

  testWidgets('with approval on, the draft offers submit, not post', (
    tester,
  ) async {
    wiring.settings.salesApprovalRequired = true;
    final id = await seedDraft();
    await pumpInventrix(tester, wiring, location: '$base/$id');
    expect(find.byKey(const Key('post_sale')), findsNothing);
    await tapKey(tester, 'submit_sale');
    expect(find.byKey(const Key('status_pendingApproval')), findsOneWidget);
    await tapKey(tester, 'approve_sale');
    expect(find.byKey(const Key('status_approved')), findsOneWidget);
    expect(find.byKey(const Key('post_sale')), findsOneWidget);
  });

  testWidgets('cancelling a draft needs confirmation', (tester) async {
    final id = await seedDraft();
    await pumpInventrix(tester, wiring, location: '$base/$id');
    await tapKey(tester, 'cancel_sale');
    await tester.tap(find.text('Cancel sale').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('status_cancelled')), findsOneWidget);
    expect(wiring.inventory.ledger.length, 1);
  });

  testWidgets('the line sheet refuses more than the stock', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await tapKey(tester, 'add_line');
    await tapKey(tester, 'line_product');
    await tester.tap(find.textContaining('Hammer').last);
    await tester.pumpAndSettle();
    await enter(tester, 'line_quantity', '51');
    await tapKey(tester, 'save_line');
    expect(find.textContaining('Only 50'), findsOneWidget);
    expect(find.byKey(const Key('line_0')), findsNothing);
  });

  testWidgets('a posted sale offers to share its invoice', (tester) async {
    final id = await seedDraft();
    (await wiring.locator<PostSale>()(id)).valueOrNull!;
    await pumpInventrix(tester, wiring, location: '$base/$id');
    await tapKey(tester, 'share_invoice');
    expect(wiring.fileSharer.shared.single.fileName, 'INV-000001.pdf');
  });

  testWidgets('an unknown sale id shows not found', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/missing');
    expect(find.text('Sale not found'), findsOneWidget);
  });

  testWidgets('a posted sale cannot be opened for editing', (tester) async {
    final id = await seedDraft();
    (await wiring.locator<PostSale>()(id)).valueOrNull!;
    await pumpInventrix(tester, wiring, location: '$base/$id/edit');
    expect(find.byKey(const Key('sales_blocked')), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('save_sale')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('the customer screen shows what is owed', (tester) async {
    final id = await seedDraft(qty: '2', price: '50');
    (await wiring.locator<PostSale>()(id)).valueOrNull!;
    await pumpInventrix(
      tester,
      wiring,
      location: '/more/customers/$customerId',
    );
    expect(find.byKey(const Key('party_balance')), findsOneWidget);
    expect(find.textContaining('100.00'), findsWidgets);
  });
}
