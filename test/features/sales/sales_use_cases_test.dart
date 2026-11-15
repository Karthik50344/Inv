import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/usecases/transition_sale.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/domain_fixture.dart';
import '../../support/sales_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late SalesFixture f;

  setUp(() => f = SalesFixture());

  /// A product selling at [price] with [stock] units received at [cost].
  Future<String> product({
    String name = 'Hammer',
    String price = '10',
    String stock = '100',
    String cost = '4',
  }) async {
    final p = await f.addProduct(name: name, selling: price);
    if (stock != '0') {
      await f.stockUp(p.id, stock, unitCost: cost);
    }
    return p.id;
  }

  SalesLineInput line(String productId, String qty, {String price = ''}) =>
      SalesLineInput(productId: productId, quantity: qty, unitPrice: price);

  Future<dynamic> balance(String productId) async =>
      (await f.inventory.getBalance(productId)).valueOrNull!;

  group('SaveSalesDraft', () {
    test('saves a draft with totals and does not touch stock', () async {
      final p = await product(stock: '20');
      final ledgerBefore = f.inventory.ledger.length;
      final invoice = await f.draft([line(p, '10', price: '12.50')]);
      expect(invoice.status, DocumentStatus.draft);
      expect(invoice.number, isNull);
      expect(invoice.displayNumber, 'Draft');
      expect(invoice.customerName, 'Acme Traders');
      expect(invoice.customerId, 'c1');
      expect(invoice.lines.single.lineNo, 1);
      expect(invoice.totals.total, inr(12500));
      expect(f.inventory.ledger.length, ledgerBefore);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(20));
      expect(f.sequences.counters, isEmpty);
      expect(f.audit.entries.last.action, 'draft_created');
    });

    test('blank price uses the product selling price', () async {
      final p = await product(price: '7.25');
      final invoice = await f.draft([line(p, '2')]);
      expect(invoice.lines.single.unitPrice, inr(725));
      expect(invoice.totals.total, inr(1450));
    });

    test('a sale without a customer is a walk-in sale', () async {
      final p = await product();
      final invoice = await f.draft([line(p, '1')], customerId: null);
      expect(invoice.customerId, isNull);
      expect(invoice.customerName, SalesInvoice.walkInCustomerName);
      final posted = (await f.post(invoice.id)).valueOrNull!;
      expect(posted.customerName, 'Walk-in customer');
      expect(posted.number, 'INV-000001');
    });

    test('snapshots product name, sku and unit on the line', () async {
      final p = await f.addProduct(name: 'Hammer', sku: 'H-1', selling: '5');
      await f.stockUp(p.id, '5');
      final invoice = await f.draft([line(p.id, '1')]);
      final l = invoice.lines.single;
      expect(l.productName, 'Hammer');
      expect(l.sku, 'H-1');
      expect(l.unitSymbol, 'pcs');
    });

    test('totals are the sum of the lines', () async {
      final a = await product(name: 'A', price: '10');
      final b = await product(name: 'B', price: '3.33');
      final invoice = await f.draft([
        line(a, '3'),
        SalesLineInput(
          productId: b,
          quantity: '3',
          discountKind: DiscountKind.percent,
          discountValue: '10',
        ),
      ]);
      var sum = inr(0);
      for (final l in invoice.lines) {
        sum += l.total;
      }
      expect(invoice.totals.total, sum);
      expect(invoice.lines.length, 2);
    });

    test('validates customer, lines and fields', () async {
      final p = await product();
      var r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'nope',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('customerId'));
      r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: null,
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('invoiceDate'));
      r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: const [],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('lines'));
      r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
          notes: 'x' * 501,
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('notes'));
    });

    test('rejects an archived customer and an archived product', () async {
      final p = await product();
      final c = f.customers.items['c1']!;
      f.customers.items['c1'] = c.archived(f.clock.now());
      var r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('customerId'));
      f.customers.items['c1'] = c;
      final product0 = f.products.items[p]!;
      f.products.items[p] = product0.archived(f.clock.now());
      r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('lines.0.product'));
    });

    test('reports line errors by index and field', () async {
      final p = await product();
      final r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [
            line(p, '1'),
            line(p, '0'),
            line(p, '1', price: 'abc'),
            line(p, '1.5'),
          ],
        ),
      );
      final keys = fieldErrorsOf(r).keys;
      expect(keys, contains('lines.1.quantity'));
      expect(keys, contains('lines.2.unitPrice'));
      expect(keys, contains('lines.3.quantity'));
      expect(keys.contains('lines.0.quantity'), isFalse);
    });

    test('rejects a due date before the invoice date', () async {
      final p = await product();
      final r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          dueDate: DateTime.utc(2026, 1, 4),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('dueDate'));
    });

    test('editing replaces the lines and keeps creation time', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      f.clock.advance(const Duration(hours: 2));
      final edited = await f.draft([line(p, '3')], id: d.id);
      expect(edited.id, d.id);
      expect(edited.lines.single.quantity, Quantity.fromUnits(3));
      expect(edited.createdAt, d.createdAt);
      expect(edited.updatedAt.isAfter(d.updatedAt), isTrue);
      expect(f.sales.items.length, 1);
      expect(f.audit.entries.last.action, 'draft_updated');
    });

    test('only drafts can be edited', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      (await f.post(d.id)).valueOrNull!;
      final r = await f.saveDraft(
        SalesDraftInput(
          id: d.id,
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '2')],
        ),
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.sales.items[d.id]!.lines.single.quantity, Quantity.fromUnits(1));
    });

    test('a failed write rolls the draft back', () async {
      final p = await product();
      f.audit.recordFailure = const DatabaseFailure('audit down');
      final r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(f.sales.items, isEmpty);
    });
  });

  group('stock availability on drafts', () {
    test('a line above the stock on hand is rejected', () async {
      final p = await product(stock: '5');
      final r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '6')],
        ),
      );
      final errors = fieldErrorsOf(r);
      expect(errors['lines.0.quantity'], contains('Only 5'));
      expect(f.sales.items, isEmpty);
    });

    test('exactly the stock on hand is accepted', () async {
      final p = await product(stock: '5');
      final d = await f.draft([line(p, '5')]);
      expect(d.lines.single.quantity, Quantity.fromUnits(5));
    });

    test('lines of the same product are checked cumulatively', () async {
      final p = await product(stock: '10');
      final r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '6'), line(p, '6')],
        ),
      );
      final errors = fieldErrorsOf(r);
      expect(errors.containsKey('lines.0.quantity'), isFalse);
      expect(errors.containsKey('lines.1.quantity'), isTrue);
    });

    test('a product that was never stocked cannot be sold', () async {
      final p = await product(stock: '0');
      final r = await f.saveDraft(
        SalesDraftInput(
          customerId: 'c1',
          invoiceDate: DateTime.utc(2026, 1, 5),
          lines: [line(p, '1')],
        ),
      );
      expect(fieldErrorsOf(r).keys, contains('lines.0.quantity'));
    });
  });

  group('PostSale', () {
    test('takes stock out at average cost, numbers and posts', () async {
      final p = await product(stock: '10', cost: '4');
      final d = await f.draft([line(p, '3', price: '10')]);
      final posted = (await f.post(d.id)).valueOrNull!;
      expect(posted.status, DocumentStatus.posted);
      expect(posted.number, 'INV-000001');
      expect(posted.postedAt, isNotNull);
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.fromUnits(7));
      expect(b.inventoryValue, inr(2800));
      final sale = f.inventory.ledger.last;
      expect(sale.type, StockMovementType.sale);
      expect(sale.quantityDelta, Quantity.fromUnits(-3));
      expect(sale.totalCost, inr(-1200));
      expect(sale.sourceId, d.id);
      expect(sale.sourceLineId, d.lines.single.id);
      expect(f.audit.entries.last.action, 'posted');
    });

    test('the cost of goods sold is the weighted average cost', () async {
      final p = await product(stock: '10', cost: '4');
      await f.stockUp(p, '10', unitCost: '6'); // avg 5
      final d = await f.draft([line(p, '4', price: '9')]);
      await f.post(d.id);
      expect(f.inventory.ledger.last.totalCost, inr(-2000));
      expect((await balance(p)).inventoryValue, inr(8000));
    });

    test('selling the last unit takes the whole remaining value', () async {
      final p = await product(stock: '3', cost: '3.33');
      final d = await f.draft([line(p, '3')]);
      await f.post(d.id);
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.zero);
      expect(b.inventoryValue, inr(0));
    });

    test('two lines of the same product both leave stock', () async {
      final p = await product(stock: '10');
      final d = await f.draft([line(p, '4'), line(p, '5')]);
      await f.post(d.id);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(1));
      final sales = f.inventory.ledger.where(
        (m) => m.type == StockMovementType.sale,
      );
      expect(sales.length, 2);
    });

    test('insufficient stock at posting is rejected and rolls back', () async {
      final p = await product(stock: '10');
      final d = await f.draft([line(p, '8')]);
      // Someone else takes stock out after the draft was saved.
      await f.adjustStock(
        productId: p,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '5',
        reason: 'Damaged',
      );
      final ledgerBefore = f.inventory.ledger.length;
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<InsufficientStockFailure>());
      expect(r.failureOrNull!.message, contains('Hammer'));
      expect(f.sales.items[d.id]!.status, DocumentStatus.draft);
      expect(f.sales.items[d.id]!.number, isNull);
      expect(f.inventory.ledger.length, ledgerBefore);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(5));
      expect(f.sequences.counters, isEmpty);
    });

    test('a shortage on a later line rolls back the earlier lines', () async {
      final a = await product(name: 'A', stock: '10');
      final b = await product(name: 'B', stock: '10');
      final d = await f.draft([line(a, '4'), line(b, '4')]);
      await f.adjustStock(
        productId: b,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '8',
        reason: 'Lost',
      );
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<InsufficientStockFailure>());
      expect((await balance(a)).quantityOnHand, Quantity.fromUnits(10));
      expect(f.sales.items[d.id]!.status, DocumentStatus.draft);
    });

    test('stock can never go negative through posting', () async {
      final p = await product(stock: '2');
      final d = await f.draft([line(p, '2')]);
      (await f.post(d.id)).valueOrNull!;
      final again = await f
          .draft([line(p, '1')])
          .then((_) => null)
          .onError(
            (_, __) => null,
          );
      expect(again, isNull);
      expect((await balance(p)).quantityOnHand, Quantity.zero);
    });

    test('numbers are sequential', () async {
      final p = await product();
      final a = (await f.post((await f.draft([line(p, '1')])).id)).valueOrNull!;
      final b = (await f.post((await f.draft([line(p, '1')])).id)).valueOrNull!;
      expect(a.number, 'INV-000001');
      expect(b.number, 'INV-000002');
    });

    test('posting twice is rejected and changes nothing', () async {
      final p = await product(stock: '10');
      final d = await f.draft([line(p, '3')]);
      (await f.post(d.id)).valueOrNull!;
      final ledger = f.inventory.ledger.length;
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.inventory.ledger.length, ledger);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(7));
      expect(f.sequences.counters['sales_invoice'], 1);
    });

    test('cancelled and unknown sales cannot be posted', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      (await f.transition(d.id, SaleAction.cancel)).valueOrNull!;
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
      expect((await f.post('nope')).failureOrNull, isA<NotFoundFailure>());
    });

    test('an archived product blocks posting', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      f.products.items[p] = f.products.items[p]!.archived(f.clock.now());
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.sales.items[d.id]!.status, DocumentStatus.draft);
    });

    test('an archived customer blocks posting; walk-in sales do not', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      f.customers.items['c1'] = f.customers.items['c1']!.archived(
        f.clock.now(),
      );
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
      final walkIn = await f.draft([line(p, '1')], customerId: null);
      expect((await f.post(walkIn.id)).isSuccess, isTrue);
    });

    test('a tampered line is caught before posting', () async {
      final p = await product();
      final d = await f.draft([line(p, '2', price: '10')]);
      f.sales.items[d.id] = SalesInvoiceTamper.withTotal(
        f.sales.items[d.id]!,
        inr(1),
      );
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(
        f.inventory.ledger.where((m) => m.type == StockMovementType.sale),
        isEmpty,
      );
    });

    test('a failure part-way rolls everything back', () async {
      final p = await product(stock: '10');
      final d = await f.draft([line(p, '3', price: '10')]);
      f.audit.recordFailure = const DatabaseFailure('audit down');
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(f.sales.items[d.id]!.status, DocumentStatus.draft);
      expect(f.sales.items[d.id]!.number, isNull);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(10));
      expect(f.sequences.counters, isEmpty);
      f.audit.recordFailure = null;
      expect((await f.post(d.id)).valueOrNull!.number, 'INV-000001');
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(7));
    });

    test('a stock write failure rolls back the status and number', () async {
      final p = await product(stock: '10');
      final d = await f.draft([line(p, '3')]);
      f.inventory.applyFailure = const DatabaseFailure('disk');
      expect((await f.post(d.id)).isFailure, isTrue);
      expect(f.sales.items[d.id]!.status, DocumentStatus.draft);
      expect(f.sequences.counters, isEmpty);
    });

    test('the invoice keeps its snapshots after the product changes', () async {
      final p = await product(price: '10');
      final d = await f.draft([line(p, '2')]);
      final posted = (await f.post(d.id)).valueOrNull!;
      final old = f.products.items[p]!;
      f.products.items[p] = Product(
        id: old.id,
        sku: old.sku,
        name: 'Renamed',
        unitId: old.unitId,
        purchasePrice: old.purchasePrice,
        sellingPrice: inr(9999),
        priceIncludesTax: old.priceIncludesTax,
        reorderLevel: old.reorderLevel,
        createdAt: old.createdAt,
        updatedAt: old.updatedAt,
      );
      final stored = (await f.sales.getById(d.id)).valueOrNull!;
      expect(stored.lines.single.productName, 'Hammer');
      expect(stored.lines.single.unitPrice, inr(1000));
      expect(stored, posted);
    });

    test('ledger and balances reconcile after several sales', () async {
      final a = await product(name: 'A', stock: '50');
      final b = await product(name: 'B', price: '3', stock: '50', cost: '1.5');
      for (final qty in ['1', '4', '7']) {
        (await f.post(
          (await f.draft([line(a, qty), line(b, qty)])).id,
        )).valueOrNull!;
      }
      final report = (await f.reconcile()).valueOrNull!;
      expect(report.isConsistent, isTrue);
    });
  });

  group('tax and discounts on a posted sale', () {
    test(
      'tax-exclusive: tax is added on top of the discounted amount',
      () async {
        f.addTaxRate();
        final p = await f.addTaxedProduct(taxRateId: 'gst18', selling: '100');
        await f.stockUp(p.id, '10');
        final d = await f.draft([
          SalesLineInput(
            productId: p.id,
            quantity: '2',
            discountKind: DiscountKind.percent,
            discountValue: '10',
          ),
        ]);
        final l = d.lines.single;
        expect(l.gross, inr(20000));
        expect(l.discountAmount, inr(2000));
        expect(l.net, inr(18000));
        expect(l.tax, inr(3240));
        expect(l.total, inr(21240));
        expect(l.taxName, 'GST 18%');
        expect(l.taxRateBp, 1800);
      },
    );

    test('tax-inclusive: the entered price already contains the tax', () async {
      f.addTaxRate();
      final p = await f.addTaxedProduct(
        taxRateId: 'gst18',
        selling: '118',
        inclusive: true,
      );
      await f.stockUp(p.id, '10');
      final d = await f.draft([line(p.id, '1')]);
      final l = d.lines.single;
      expect(l.total, inr(11800));
      expect(l.net, inr(10000));
      expect(l.tax, inr(1800));
    });

    test('stock cost is not affected by sale tax or price', () async {
      f.addTaxRate();
      final p = await f.addTaxedProduct(taxRateId: 'gst18', selling: '100');
      await f.stockUp(p.id, '10', unitCost: '40');
      final d = await f.draft([line(p.id, '2')]);
      await f.post(d.id);
      expect(f.inventory.ledger.last.totalCost, inr(-8000));
    });
  });

  group('approval workflow', () {
    test('submit is refused when approval is not enabled', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      final r = await f.transition(d.id, SaleAction.submit);
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('with approval on, posting needs submit then approve', () async {
      f.settings.salesApprovalRequired = true;
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
      expect(
        (await f.transition(d.id, SaleAction.submit)).valueOrNull!.status,
        DocumentStatus.pendingApproval,
      );
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
      expect(
        (await f.transition(d.id, SaleAction.approve)).valueOrNull!.status,
        DocumentStatus.approved,
      );
      expect((await f.post(d.id)).valueOrNull!.status, DocumentStatus.posted);
    });

    test('reopen returns a pending sale to draft', () async {
      f.settings.salesApprovalRequired = true;
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      await f.transition(d.id, SaleAction.submit);
      final r = await f.transition(d.id, SaleAction.reopen);
      expect(r.valueOrNull!.status, DocumentStatus.draft);
    });

    test('invalid transitions are rejected', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      expect(
        (await f.transition(d.id, SaleAction.approve)).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await f.transition(d.id, SaleAction.reopen)).failureOrNull,
        isA<ValidationFailure>(),
      );
      (await f.transition(d.id, SaleAction.cancel)).valueOrNull!;
      expect(
        (await f.transition(d.id, SaleAction.cancel)).failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('a posted sale cannot be cancelled', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      (await f.post(d.id)).valueOrNull!;
      expect(
        (await f.transition(d.id, SaleAction.cancel)).failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });

  group('VoidSale', () {
    test('is refused while payments are allocated to the sale', () async {
      final p = await product(stock: '10', cost: '4');
      final d = await f.draft([line(p, '3', price: '10')]);
      (await f.post(d.id)).valueOrNull!;
      f.guard.active = true;
      final r = await f.voidSale(d.id, reason: 'Wrong customer');
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.sales.items[d.id]!.status, DocumentStatus.posted);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(7));
      f.guard.active = false;
      expect((await f.voidSale(d.id, reason: 'Wrong customer')).isSuccess,
          isTrue);
    });

    test('puts the stock back and keeps the document', () async {
      final p = await product(stock: '10', cost: '4');
      final d = await f.draft([line(p, '3', price: '10')]);
      (await f.post(d.id)).valueOrNull!;
      final voided = (await f.voidSale(
        d.id,
        reason: 'Wrong customer',
      )).valueOrNull!;
      expect(voided.status, DocumentStatus.voided);
      expect(voided.number, 'INV-000001');
      expect(voided.voidReason, 'Wrong customer');
      expect(voided.totals, f.sales.items[d.id]!.totals);
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.fromUnits(10));
      expect(b.inventoryValue, inr(4000));
      final rev = f.inventory.ledger.last;
      expect(rev.type, StockMovementType.reversal);
      expect(rev.quantityDelta, Quantity.fromUnits(3));
      expect(rev.totalCost, inr(1200));
      // The original sale movement is still in the ledger.
      expect(
        f.inventory.ledger.where((m) => m.type == StockMovementType.sale),
        hasLength(1),
      );
      expect(f.audit.entries.last.action, 'voided');
    });

    test(
      'returns stock at the cost it left with, not the current cost',
      () async {
        final p = await product(stock: '10', cost: '4');
        final d = await f.draft([line(p, '5')]);
        (await f.post(d.id)).valueOrNull!; // cost 2000, 5 left worth 2000
        await f.stockUp(p, '5', unitCost: '10'); // avg changes
        (await f.voidSale(d.id, reason: 'Mistake')).valueOrNull!;
        final b = await balance(p);
        expect(b.quantityOnHand, Quantity.fromUnits(15));
        expect(b.inventoryValue, inr(2000 + 5000 + 2000));
      },
    );

    test('works when the stock was sold out completely', () async {
      final p = await product(stock: '2', cost: '3');
      final d = await f.draft([line(p, '2')]);
      (await f.post(d.id)).valueOrNull!;
      expect((await balance(p)).quantityOnHand, Quantity.zero);
      (await f.voidSale(d.id, reason: 'Mistake')).valueOrNull!;
      final b = await balance(p);
      expect(b.quantityOnHand, Quantity.fromUnits(2));
      expect(b.inventoryValue, inr(600));
    });

    test('needs a reason and a posted sale', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      expect(
        fieldErrorsOf(await f.voidSale(d.id, reason: '  ')).keys,
        contains('reason'),
      );
      expect(
        (await f.voidSale(d.id, reason: 'x')).failureOrNull,
        isA<ValidationFailure>(),
      );
      (await f.post(d.id)).valueOrNull!;
      (await f.voidSale(d.id, reason: 'x')).valueOrNull!;
      final ledger = f.inventory.ledger.length;
      expect(
        (await f.voidSale(d.id, reason: 'again')).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(f.inventory.ledger.length, ledger);
    });

    test('a failure rolls the void back', () async {
      final p = await product(stock: '10');
      final d = await f.draft([line(p, '3')]);
      (await f.post(d.id)).valueOrNull!;
      f.audit.recordFailure = const DatabaseFailure('down');
      expect((await f.voidSale(d.id, reason: 'x')).isFailure, isTrue);
      expect(f.sales.items[d.id]!.status, DocumentStatus.posted);
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(7));
    });

    test('ledger and balances reconcile after post and void', () async {
      final p = await product(stock: '20');
      final a = await f.draft([line(p, '5')]);
      final b = await f.draft([line(p, '7')]);
      await f.post(a.id);
      await f.post(b.id);
      await f.voidSale(a.id, reason: 'x');
      expect((await balance(p)).quantityOnHand, Quantity.fromUnits(13));
      expect((await f.reconcile()).valueOrNull!.isConsistent, isTrue);
    });

    test('a voided sale cannot be posted again', () async {
      final p = await product();
      final d = await f.draft([line(p, '1')]);
      await f.post(d.id);
      await f.voidSale(d.id, reason: 'x');
      expect((await f.post(d.id)).failureOrNull, isA<ValidationFailure>());
    });
  });

  group('GetCustomerReceivable', () {
    test('adds posted sales to the opening balance', () async {
      final p = await product(stock: '20');
      f.customers.items['c1'] = Customer(
        id: 'c1',
        name: 'Acme Traders',
        openingBalance: inr(5000),
        createdAt: f.clock.now(),
        updatedAt: f.clock.now(),
      );
      final a = await f.draft([line(p, '2', price: '10')]); // 2000
      final b = await f.draft([line(p, '1', price: '10')]); // 1000
      await f.post(a.id);
      final r = (await f.receivable('c1')).valueOrNull!;
      expect(r.sales, inr(2000));
      expect(r.outstanding, inr(7000));
      expect(b.status, DocumentStatus.draft); // drafts never count
    });

    test('voided and cancelled sales do not count', () async {
      final p = await product(stock: '20');
      final a = await f.draft([line(p, '2', price: '10')]);
      final b = await f.draft([line(p, '1', price: '10')]);
      await f.post(a.id);
      await f.voidSale(a.id, reason: 'x');
      await f.transition(b.id, SaleAction.cancel);
      expect((await f.receivable('c1')).valueOrNull!.outstanding, inr(0));
    });

    test('walk-in sales belong to no customer', () async {
      final p = await product(stock: '20');
      final w = await f.draft([line(p, '2', price: '10')], customerId: null);
      await f.post(w.id);
      expect((await f.receivable('c1')).valueOrNull!.sales, inr(0));
    });

    test('unknown customers are not found', () async {
      expect((await f.receivable('zz')).failureOrNull, isA<NotFoundFailure>());
    });
  });
}
