import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/usecases/transition_purchase.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/domain_fixture.dart';
import '../../support/purchase_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late PurchaseFixture f;

  setUp(() => f = PurchaseFixture());

  Future<String> product({String name = 'Hammer', String price = '10'}) async =>
      (await f.addProduct(name: name, purchase: price)).id;

  PurchaseLineInput line(String productId, String qty, {String price = ''}) =>
      PurchaseLineInput(productId: productId, quantity: qty, unitPrice: price);

  Future<dynamic> balance(String productId) async =>
      (await f.inventory.getBalance(productId)).valueOrNull!;

  group('SavePurchaseDraft', () {
    test('saves a draft with totals and does not touch stock', () async {
      final p = await product();
      final invoice = await f.draft([line(p, '10', price: '12.50')]);
      expect(invoice.status, DocumentStatus.draft);
      expect(invoice.number, isNull);
      expect(invoice.displayNumber, 'Draft');
      expect(invoice.supplierName, 'Acme Supplies');
      expect(invoice.lines.single.lineNo, 1);
      expect(invoice.totals.total, inr(12500));
      expect(f.inventory.ledger, isEmpty);
      expect((await balance(p)).quantityOnHand, Quantity.zero);
      expect(f.sequences.counters, isEmpty);
      expect(f.audit.entries.single.action, 'draft_created');
    });

    test('blank price uses the product purchase price', () async {
      final p = await product(price: '7.25');
      final invoice = await f.draft([line(p, '2')]);
      expect(invoice.lines.single.unitPrice, inr(725));
      expect(invoice.totals.total, inr(1450));
    });

    test('snapshots product name, sku and unit on the line', () async {
      final p = await f.addProduct(name: 'Hammer', sku: 'H-1');
      final invoice = await f.draft([line(p.id, '1')]);
      final l = invoice.lines.single;
      expect(l.productName, 'Hammer');
      expect(l.sku, 'H-1');
      expect(l.unitSymbol, 'pcs');
      expect(l.unitDecimalPlaces, 0);
    });

    test('totals are the sum of the lines', () async {
      f.addTaxRate();
      final a = await f.addTaxedProduct(name: 'A', taxRateId: 'gst18');
      final b = await f.addTaxedProduct(name: 'B', purchase: '50');
      final invoice = await f.draft([
        line(a.id, '2'),
        PurchaseLineInput(
          productId: b.id,
          quantity: '3',
          discountKind: DiscountKind.percent,
          discountValue: '10',
        ),
      ]);
      // A: 200 + 36 tax = 236 ; B: 150 - 15 = 135
      expect(invoice.totals.gross, inr(35000));
      expect(invoice.totals.discount, inr(1500));
      expect(invoice.totals.net, inr(33500));
      expect(invoice.totals.tax, inr(3600));
      expect(invoice.totals.total, inr(37100));
    });

    test('validates supplier, lines and fields', () async {
      final p = await product();
      var r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: '',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('supplierId'));

      r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: 's1',
          invoiceDate: null,
          lines: const [],
        ),
      );
      expect(fieldErrorsOf(r).keys, containsAll(['invoiceDate', 'lines']));

      r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: 'missing',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('supplierId'));
      expect(f.purchases.items, isEmpty);
    });

    test('rejects an archived supplier and an archived product', () async {
      final p = await product();
      f.suppliers.items['s1'] = f.suppliers.items['s1']!.archived(
        f.clock.now(),
      );
      var r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: 's1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('supplierId'));

      f.addSupplier(id: 's2', name: 'Other');
      f.products.items[p] = f.products.items[p]!.archived(f.clock.now());
      r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: 's2',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('lines.0.product'));
    });

    test('reports line errors by index and field', () async {
      final p = await product();
      final r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: 's1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [
            line(p, '1'),
            line(p, '1.5'), // pcs allows whole numbers only
            line(p, '0'),
            line(p, '1', price: '-3'),
            PurchaseLineInput(
              productId: p,
              quantity: '1',
              discountKind: DiscountKind.amount,
              discountValue: '999',
            ),
          ],
        ),
      );
      final errors = fieldErrorsOf(r);
      expect(errors.keys, isNot(contains('lines.0.quantity')));
      expect(errors['lines.1.quantity'], isNotNull);
      expect(errors['lines.2.quantity'], isNotNull);
      expect(errors['lines.3.unitPrice'], isNotNull);
      expect(errors['lines.4.discount'], isNotNull);
    });

    test('rejects a due date before the invoice date', () async {
      final p = await product();
      final r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: 's1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          dueDate: DateTime.utc(2026, 1, 4),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('dueDate'));
    });

    test('percent discount over 100% and bad text are rejected', () async {
      final p = await product();
      for (final text in ['100.01', 'abc', '-1', '']) {
        final r = await f.saveDraft(
          PurchaseDraftInput(
            supplierId: 's1',
            invoiceDate: DateTime.utc(2026, 1, 5),
            lines: [
              PurchaseLineInput(
                productId: p,
                quantity: '1',
                discountKind: DiscountKind.percent,
                discountValue: text,
              ),
            ],
          ),
        );
        expect(
          fieldErrorsOf(r).keys,
          contains('lines.0.discount'),
          reason: text,
        );
      }
    });

    test('editing replaces the lines and keeps creation time', () async {
      final a = await product(name: 'A');
      final b = await product(name: 'B');
      final first = await f.draft([line(a, '1')]);
      f.clock.advance(const Duration(hours: 1));
      final second = await f.draft([line(b, '4')], id: first.id);
      expect(second.id, first.id);
      expect(second.createdAt, first.createdAt);
      expect(second.updatedAt.isAfter(first.updatedAt), isTrue);
      expect(f.purchases.items.length, 1);
      expect(second.lines.single.productId, b);
      expect(f.audit.entries.last.action, 'draft_updated');
    });

    test('only drafts can be edited', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      (await f.post(d.id)).valueOrNull!;
      final r = await f.saveDraft(
        PurchaseDraftInput(
          id: d.id,
          supplierId: 's1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '2')],
        ),
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(
        f.purchases.items[d.id]!.lines.single.quantity,
        Quantity.fromUnits(1),
      );
    });

    test('a failed write rolls the draft back', () async {
      final p = await product();
      f.audit.recordFailure = const DatabaseFailure('boom');
      final r = await f.saveDraft(
        PurchaseDraftInput(
          supplierId: 's1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(f.purchases.items, isEmpty);
    });
  });

  group('PostPurchase', () {
    test('adds stock at cost, assigns a number, marks posted', () async {
      final p = await product();
      final d = await f.draft([line(p, '10', price: '12.50')]);
      final posted = (await f.post(d.id)).valueOrNull!;
      expect(posted.status, DocumentStatus.posted);
      expect(posted.number, 'PUR-000001');
      expect(posted.postedAt, isNotNull);
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.fromUnits(10));
      expect(b.inventoryValue, inr(12500));
      final m = f.inventory.ledger.single;
      expect(m.type, StockMovementType.purchase);
      expect(m.sourceType, 'purchase_invoice');
      expect(m.sourceId, d.id);
      expect(m.sourceLineId, d.lines.single.id);
      expect(m.totalCost, inr(12500));
      expect(f.audit.entries.last.action, 'posted');
    });

    test('weighted average cost across purchases', () async {
      final p = await product();
      (await f.post((await f.draft([line(p, '10', price: '10')])).id))
          .valueOrNull!;
      (await f.post((await f.draft([line(p, '10', price: '20')])).id))
          .valueOrNull!;
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.fromUnits(20));
      expect(b.inventoryValue, inr(30000));
      expect(b.averageCost, inr(1500));
    });

    test('two lines of the same product both count', () async {
      final p = await product();
      final d = await f.draft([
        line(p, '2', price: '10'),
        line(p, '3', price: '20'),
      ]);
      (await f.post(d.id)).valueOrNull!;
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.fromUnits(5));
      expect(b.inventoryValue, inr(8000));
      expect(f.inventory.ledger.length, 2);
    });

    test('inventory cost excludes tax and includes the discount', () async {
      f.addTaxRate();
      final p = await f.addTaxedProduct(taxRateId: 'gst18');
      final d = await f.draft([
        PurchaseLineInput(
          productId: p.id,
          quantity: '2',
          discountKind: DiscountKind.percent,
          discountValue: '10',
        ),
      ]);
      // gross 200, discount 20, net 180, tax 32.40, total 212.40
      expect(d.totals.total, inr(21240));
      (await f.post(d.id)).valueOrNull!;
      expect((await balance(p.id)).inventoryValue, inr(18000));
    });

    test('tax-inclusive prices cost the net amount', () async {
      f.addTaxRate();
      final p = await f.addTaxedProduct(
        taxRateId: 'gst18',
        inclusive: true,
        purchase: '118',
      );
      (await f.post((await f.draft([line(p.id, '1')])).id)).valueOrNull!;
      expect((await balance(p.id)).inventoryValue, inr(10000));
    });

    test('numbers are sequential', () async {
      final p = await product();
      final a = (await f.post((await f.draft([line(p, '1')])).id)).valueOrNull!;
      final b = (await f.post((await f.draft([line(p, '1')])).id)).valueOrNull!;
      expect(a.number, 'PUR-000001');
      expect(b.number, 'PUR-000002');
    });

    test('posting twice is rejected and changes nothing', () async {
      final p = await product();
      final d = await f.draft([line(p, '5')]);
      (await f.post(d.id)).valueOrNull!;
      final again = await f.post(d.id);
      expect(again.failureOrNull, isA<ValidationFailure>());
      expect(f.inventory.ledger.length, 1);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(5));
      expect(f.sequences.counters['purchase_invoice'], 1);
    });

    test('cancelled and unknown purchases cannot be posted', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      (await f.transition(d.id, PurchaseAction.cancel)).valueOrNull!;
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
      expect((await f.post('nope')).failureOrNull, isA<NotFoundFailure>());
      expect(f.inventory.ledger, isEmpty);
    });

    test('an archived product blocks posting', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      f.products.items[p] = f.products.items[p]!.archived(f.clock.now());
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.purchases.items[d.id]!.status, DocumentStatus.draft);
    });

    test('an archived supplier blocks posting', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      f.suppliers.items['s1'] = f.suppliers.items['s1']!.archived(
        f.clock.now(),
      );
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
    });

    test('a tampered line is caught before posting', () async {
      final p = await product();
      final d = await f.draft([line(p, '2', price: '10')]);
      final tampered = f.purchases.items[d.id]!;
      f.purchases.items[d.id] = PurchaseInvoiceTamper.withTotal(
        tampered,
        inr(1),
      );
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.inventory.ledger, isEmpty);
    });

    test('a failure part-way rolls everything back', () async {
      final p = await product();
      final d = await f.draft([line(p, '3', price: '10')]);
      f.audit.recordFailure = const DatabaseFailure('audit down');
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(f.purchases.items[d.id]!.status, DocumentStatus.draft);
      expect(f.purchases.items[d.id]!.number, isNull);
      expect(f.inventory.ledger, isEmpty);
      expect((await balance(p)).quantityOnHand, Quantity.zero);
      expect(f.sequences.counters, isEmpty);
      // Retrying after the problem is fixed works and uses number 1.
      f.audit.recordFailure = null;
      expect((await f.post(d.id)).valueOrNull!.number, 'PUR-000001');
    });

    test('a stock write failure rolls back the status and number', () async {
      final p = await product();
      final d = await f.draft([line(p, '3')]);
      f.inventory.applyFailure = const DatabaseFailure('disk');
      expect((await f.post(d.id)).isFailure, isTrue);
      expect(f.purchases.items[d.id]!.status, DocumentStatus.draft);
      expect(f.sequences.counters, isEmpty);
    });

    test('ledger and balances reconcile after several purchases', () async {
      final a = await product(name: 'A');
      final b = await product(name: 'B', price: '3');
      for (final qty in ['1', '4', '7']) {
        (await f.post((await f.draft([line(a, qty), line(b, qty)])).id))
            .valueOrNull!;
      }
      final report = (await f.reconcile()).valueOrNull!;
      expect(report.isConsistent, isTrue);
    });
  });

  group('approval workflow', () {
    test('submit is refused when approval is not enabled', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      final r = await f.transition(d.id, PurchaseAction.submit);
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('with approval on, posting needs submit then approve', () async {
      f.settings.purchaseApprovalRequired = true;
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());

      var r = (await f.transition(d.id, PurchaseAction.submit)).valueOrNull!;
      expect(r.status, DocumentStatus.pendingApproval);
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
      // A pending purchase cannot be edited.
      final edit = await f.saveDraft(
        PurchaseDraftInput(
          id: d.id,
          supplierId: 's1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '9')],
        ),
      );
      expect(edit.failureOrNull, isA<ValidationFailure>());

      r = (await f.transition(d.id, PurchaseAction.approve)).valueOrNull!;
      expect(r.status, DocumentStatus.approved);
      r = (await f.post(d.id)).valueOrNull!;
      expect(r.status, DocumentStatus.posted);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(1));
    });

    test('reopen returns a pending purchase to draft', () async {
      f.settings.purchaseApprovalRequired = true;
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      (await f.transition(d.id, PurchaseAction.submit)).valueOrNull!;
      final r = (await f.transition(d.id, PurchaseAction.reopen)).valueOrNull!;
      expect(r.status, DocumentStatus.draft);
    });

    test('invalid transitions are rejected', () async {
      f.settings.purchaseApprovalRequired = true;
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      expect(
        (await f.transition(d.id, PurchaseAction.approve)).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await f.transition(d.id, PurchaseAction.reopen)).failureOrNull,
        isA<ValidationFailure>(),
      );
      (await f.transition(d.id, PurchaseAction.cancel)).valueOrNull!;
      expect(
        (await f.transition(d.id, PurchaseAction.cancel)).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(f.purchases.items[d.id]!.cancelledAt, isNotNull);
    });

    test('a posted purchase cannot be cancelled', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      (await f.post(d.id)).valueOrNull!;
      expect(
        (await f.transition(d.id, PurchaseAction.cancel)).failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });

  group('VoidPurchase', () {
    test('is refused while payments are allocated to the purchase', () async {
      final p = await product();
      final d = await f.draft([line(p, '10', price: '10')]);
      (await f.post(d.id)).valueOrNull!;
      f.guard.active = true;
      final r = await f.voidPurchase(d.id, reason: 'Wrong supplier');
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.purchases.items[d.id]!.status, DocumentStatus.posted);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(10));
      f.guard.active = false;
      expect(
        (await f.voidPurchase(d.id, reason: 'Wrong supplier')).isSuccess,
        isTrue,
      );
    });

    test('reverses the stock and keeps the document', () async {
      final p = await product();
      final d = await f.draft([line(p, '10', price: '10')]);
      (await f.post(d.id)).valueOrNull!;
      final v = (await f.voidPurchase(
        d.id,
        reason: 'Wrong supplier',
      )).valueOrNull!;
      expect(v.status, DocumentStatus.voided);
      expect(v.number, 'PUR-000001');
      expect(v.voidReason, 'Wrong supplier');
      expect(v.totals, d.totals);
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.zero);
      expect(b.inventoryValue, inr(0));
      expect(f.inventory.ledger.length, 2);
      final reversal = f.inventory.ledger.last;
      expect(reversal.type, StockMovementType.reversal);
      expect(reversal.quantityDelta, Quantity.fromUnits(-10));
      expect(reversal.totalCost, inr(-10000));
      expect(reversal.sourceId, d.id);
      expect((await f.reconcile()).valueOrNull!.isConsistent, isTrue);
    });

    test('restores the earlier average cost', () async {
      final p = await product();
      final first = await f.draft([line(p, '10', price: '10')]);
      (await f.post(first.id)).valueOrNull!;
      (await f.post((await f.draft([line(p, '10', price: '20')])).id))
          .valueOrNull!;
      (await f.voidPurchase(first.id, reason: 'Duplicate entry')).valueOrNull!;
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.fromUnits(10));
      expect(b.averageCost, inr(2000));
    });

    test('is rejected when part of the stock was already used', () async {
      final p = await product();
      final d = await f.draft([line(p, '10', price: '10')]);
      (await f.post(d.id)).valueOrNull!;
      (await f.adjustStock(
        productId: p,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '4',
        reason: 'Damaged',
      )).valueOrNull!;
      final r = await f.voidPurchase(d.id, reason: 'Mistake');
      expect(r.failureOrNull, isA<InsufficientStockFailure>());
      expect(f.purchases.items[d.id]!.status, DocumentStatus.posted);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(6));
      expect(f.inventory.ledger.length, 2);
    });

    test('an all-or-nothing void across several lines', () async {
      final a = await product(name: 'A');
      final b = await product(name: 'B');
      final d = await f.draft([line(a, '5'), line(b, '5')]);
      (await f.post(d.id)).valueOrNull!;
      (await f.adjustStock(
        productId: b,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '1',
        reason: 'Lost',
      )).valueOrNull!;
      final r = await f.voidPurchase(d.id, reason: 'Mistake');
      expect(r.isFailure, isTrue);
      // A is untouched: the whole void rolled back.
      expect((await balance(a)).quantityOnHand, Quantity.fromUnits(5));
      expect(f.purchases.items[d.id]!.status, DocumentStatus.posted);
    });

    test('needs a reason and a posted purchase', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      expect(
        fieldErrorsOf(await f.voidPurchase(d.id, reason: '  ')).keys,
        contains('reason'),
      );
      expect(
        (await f.voidPurchase(d.id, reason: 'x')).failureOrNull,
        isA<ValidationFailure>(),
      );
      (await f.post(d.id)).valueOrNull!;
      (await f.voidPurchase(d.id, reason: 'x')).valueOrNull!;
      expect(
        (await f.voidPurchase(d.id, reason: 'again')).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(f.inventory.ledger.length, 2);
    });

    test('a failure rolls the void back', () async {
      final p = await product();
      final d = await f.draft([line(p, '3')]);
      (await f.post(d.id)).valueOrNull!;
      f.audit.recordFailure = const DatabaseFailure('down');
      expect((await f.voidPurchase(d.id, reason: 'x')).isFailure, isTrue);
      expect(f.purchases.items[d.id]!.status, DocumentStatus.posted);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(3));
    });
  });

  group('GetSupplierPayable', () {
    test('adds posted purchases to the opening balance', () async {
      final p = await product();
      final d1 = await f.draft([line(p, '2', price: '50')]);
      final d2 = await f.draft([line(p, '1', price: '30')]);
      await f.draft([line(p, '9', price: '99')]); // draft: ignored
      (await f.post(d1.id)).valueOrNull!;
      (await f.post(d2.id)).valueOrNull!;
      var payable = (await f.payable('s1')).valueOrNull!;
      expect(payable.purchases, inr(13000));
      expect(payable.outstanding, inr(13000));
      (await f.voidPurchase(d2.id, reason: 'x')).valueOrNull!;
      payable = (await f.payable('s1')).valueOrNull!;
      expect(payable.outstanding, inr(10000));
    });

    test('unknown suppliers are not found', () async {
      expect((await f.payable('nope')).failureOrNull, isA<NotFoundFailure>());
    });
  });
}
