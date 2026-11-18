import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/usecases/record_opening_stock.dart';
import 'package:inventrix/features/inventory/presentation/pages/inventory_page.dart';
import 'package:inventrix/features/inventory/presentation/pages/reconciliation_page.dart';
import 'package:inventrix/features/inventory/presentation/pages/stock_detail_page.dart';
import 'package:inventrix/features/inventory/presentation/pages/stock_operation_page.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/shared/presentation/widgets/app_button.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

void main() {
  late TestWiring wiring;

  setUp(() {
    wiring = TestWiring()
      ..addUnit()
      ..addCategory();
  });

  Future<String> addProduct(
    String name,
    String sku, {
    String reorder = '',
  }) async {
    final r = await wiring.locator<CreateProduct>()(
      ProductDraft(
        name: name,
        sku: sku,
        unitId: 'u1',
        purchasePrice: '10',
        reorderLevel: reorder,
      ),
    );
    return r.valueOrNull!.id;
  }

  Future<void> stock(String productId, String qty) async {
    await wiring.locator<RecordOpeningStock>()(
      productId: productId,
      quantity: qty,
      unitCost: '5',
    );
  }

  testWidgets('shows an empty state without products', (tester) async {
    await pumpInventrix(tester, wiring, location: '/inventory');
    expect(find.byType(InventoryPage), findsOneWidget);
    expect(find.text('No products yet'), findsOneWidget);
  });

  testWidgets('lists stock with valuation and low/out badges', (tester) async {
    final a = await addProduct('Hammer', 'H-1', reorder: '10');
    final b = await addProduct('Saw', 'S-1', reorder: '5');
    await addProduct('Drill', 'D-1', reorder: '5');
    await stock(a, '4');
    await stock(b, '20');
    await pumpInventrix(tester, wiring, location: '/inventory');
    expect(find.text('Hammer'), findsOneWidget);
    expect(find.byKey(const Key('status_low')), findsOneWidget);
    expect(find.byKey(const Key('status_out')), findsOneWidget);
    expect(find.textContaining('120.00'), findsWidgets);
    expect(find.text('1 low'), findsOneWidget);
    expect(find.text('1 out'), findsOneWidget);
  });

  testWidgets('filter chips narrow the list', (tester) async {
    final a = await addProduct('Hammer', 'H-1', reorder: '10');
    final b = await addProduct('Saw', 'S-1', reorder: '5');
    await stock(a, '4');
    await stock(b, '20');
    await pumpInventrix(tester, wiring, location: '/inventory');
    await tapKey(tester, 'filter_low');
    expect(find.text('Hammer'), findsOneWidget);
    expect(find.text('Saw'), findsNothing);
    await tapKey(tester, 'filter_all');
    expect(find.text('Saw'), findsOneWidget);
  });

  testWidgets('records opening stock through the form', (tester) async {
    await addProduct('Hammer', 'H-1');
    await pumpInventrix(tester, wiring, location: '/inventory');
    await tester.tap(find.text('Hammer'));
    await tester.pumpAndSettle();
    expect(find.byType(StockDetailPage), findsOneWidget);
    expect(find.text('No stock movements yet.'), findsOneWidget);

    await tapKey(tester, 'opening_stock');
    expect(find.byType(StockOperationPage), findsOneWidget);
    await enter(tester, 'stock_quantity_input', '10');
    await enter(tester, 'stock_unit_cost_input', '5');
    await tapKey(tester, 'save_stock_operation');

    expect(find.byType(StockDetailPage), findsOneWidget);
    expect(find.text('10 pcs'), findsOneWidget);
    expect(find.textContaining('Opening stock: +10 pcs'), findsOneWidget);
    expect(find.byKey(const Key('opening_stock')), findsNothing);
    expect(wiring.inventory.ledger.length, 1);
    expect(wiring.audit.entries.length, 1);
  });

  testWidgets('stock out requires a reason and rejects too much', (
    tester,
  ) async {
    final id = await addProduct('Hammer', 'H-1');
    await stock(id, '10');
    await pumpInventrix(tester, wiring, location: '/inventory/$id');
    await tapKey(tester, 'stock_out');

    await tapKey(tester, 'save_stock_operation');
    expect(find.text('Quantity is required.'), findsOneWidget);
    expect(find.text('A reason is required.'), findsOneWidget);

    await enter(tester, 'stock_quantity_input', '11');
    await enter(tester, 'stock_reason_input', 'Oops');
    await tapKey(tester, 'save_stock_operation');
    expect(find.textContaining('Only 10'), findsOneWidget);
    expect(wiring.inventory.balances[id]!.quantityOnHand.milli, 10000);

    await enter(tester, 'stock_quantity_input', '4');
    await tapKey(tester, 'save_stock_operation');
    expect(find.byType(StockDetailPage), findsOneWidget);
    expect(find.text('6 pcs'), findsOneWidget);
  });

  testWidgets('stock in updates quantity, value and history', (tester) async {
    final id = await addProduct('Hammer', 'H-1');
    await stock(id, '10');
    await pumpInventrix(tester, wiring, location: '/inventory/$id');
    await tapKey(tester, 'stock_in');
    await enter(tester, 'stock_quantity_input', '10');
    await enter(tester, 'stock_unit_cost_input', '15');
    await enter(tester, 'stock_reason_input', 'Delivery');
    await tapKey(tester, 'save_stock_operation');
    expect(find.text('20 pcs'), findsOneWidget);
    expect(find.textContaining('Stock in: +10 pcs'), findsOneWidget);
    expect(find.textContaining('Delivery'), findsWidgets);
  });

  testWidgets('stock-out form is blocked when there is no stock', (
    tester,
  ) async {
    final id = await addProduct('Hammer', 'H-1');
    await pumpInventrix(tester, wiring, location: '/inventory/$id/out');
    expect(find.byKey(const Key('operation_blocked')), findsOneWidget);
    final button = tester.widget<AppButton>(
      find.byKey(const Key('save_stock_operation')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('low-stock report lists only products needing attention', (
    tester,
  ) async {
    final a = await addProduct('Hammer', 'H-1', reorder: '10');
    final b = await addProduct('Saw', 'S-1', reorder: '5');
    await stock(a, '4');
    await stock(b, '20');
    await pumpInventrix(tester, wiring, location: '/inventory/low-stock');
    expect(find.text('Low-stock report'), findsOneWidget);
    expect(find.text('Hammer'), findsOneWidget);
    expect(find.text('Saw'), findsNothing);
  });

  testWidgets('low-stock report shows a friendly message when all is well', (
    tester,
  ) async {
    final b = await addProduct('Saw', 'S-1', reorder: '5');
    await stock(b, '20');
    await pumpInventrix(tester, wiring, location: '/inventory/low-stock');
    expect(find.text('Nothing needs restocking'), findsOneWidget);
  });

  testWidgets('reconciliation reports consistency and repairs mismatches', (
    tester,
  ) async {
    final id = await addProduct('Hammer', 'H-1');
    await stock(id, '10');
    await pumpInventrix(tester, wiring, location: '/inventory/reconcile');
    expect(find.byType(ReconciliationPage), findsOneWidget);
    expect(find.byKey(const Key('reconciliation_ok')), findsOneWidget);

    wiring.inventory.balances[id] = StockBalance(
      productId: id,
      quantityOnHand: const Quantity.fromMilli(1),
      inventoryValue: Money.fromMinor(1, currencyCode: 'INR', decimalPlaces: 2),
    );
    await tapKey(tester, 'run_reconciliation');
    expect(find.byKey(const Key('reconciliation_mismatch')), findsOneWidget);

    await tapKey(tester, 'repair_balances');
    await tester.tap(find.text('Repair').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reconciliation_ok')), findsOneWidget);
    expect(find.byKey(const Key('repaired_message')), findsOneWidget);
    expect(wiring.inventory.balances[id]!.quantityOnHand.milli, 10000);
  });

  testWidgets('an invalid product id shows a not-found message', (
    tester,
  ) async {
    await pumpInventrix(tester, wiring, location: '/inventory/ghost');
    expect(find.text('Product not found'), findsOneWidget);
    await pumpInventrix(tester, wiring, location: '/inventory/ghost/in');
    expect(find.text('Product not found'), findsOneWidget);
  });
}
