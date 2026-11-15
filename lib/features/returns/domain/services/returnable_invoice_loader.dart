import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_filter.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/returnable_invoice.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_filter.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Loads a posted invoice together with everything a return needs: its
/// lines, what earlier returns already took back, what the invoice has been
/// paid, and (for sales) the cost the goods left stock with.
///
/// Reads only; every figure is re-read each time, so the posting use case
/// can call it inside its transaction and never trust a stale screen.
final class ReturnableInvoiceLoader {
  /// Creates the loader.
  const ReturnableInvoiceLoader({
    required SalesRepository sales,
    required PurchaseRepository purchases,
    required ReturnRepository returns,
    required InvoiceLedger ledger,
    required InventoryRepository inventory,
  }) : _sales = sales,
       _purchases = purchases,
       _returns = returns,
       _ledger = ledger,
       _inventory = inventory;

  final SalesRepository _sales;
  final PurchaseRepository _purchases;
  final ReturnRepository _returns;
  final InvoiceLedger _ledger;
  final InventoryRepository _inventory;

  /// Loads invoice [invoiceId] or returns the reason it cannot be returned.
  Future<Result<ReturnableInvoice>> load(
    InvoiceKind kind,
    String invoiceId,
  ) async {
    try {
      return Result.success(await require(kind, invoiceId));
    } on FailureException catch (e) {
      return Result.failure(e.failure);
    }
  }

  /// Like [load] but throws a [FailureException] (so a surrounding
  /// transaction rolls back).
  Future<ReturnableInvoice> require(InvoiceKind kind, String invoiceId) async {
    final open = (await _ledger.get(kind, invoiceId)).getOrThrow();
    if (open.documentStatus != DocumentStatus.posted) {
      throw FailureException(
        ValidationFailure(
          'Only posted invoices can be returned '
          '(this one is ${open.documentStatus.label.toLowerCase()}).',
        ),
      );
    }
    final prior = (await _returns.forInvoice(kind, invoiceId)).getOrThrow();
    switch (kind) {
      case InvoiceKind.sales:
        final invoice = (await _sales.getById(invoiceId)).getOrThrow();
        final costs = await _saleCosts(invoice);
        return ReturnableInvoice(
          kind: kind,
          invoiceId: invoice.id,
          invoiceNumber: invoice.displayNumber,
          partyId: invoice.customerId,
          partyName: invoice.customerName,
          invoiceDate: invoice.invoiceDate,
          open: open,
          lines: [
            for (final line in invoice.lines)
              _line(
                prior,
                invoiceLineId: line.id,
                lineNo: line.lineNo,
                productId: line.productId,
                productName: line.productName,
                sku: line.sku,
                unitSymbol: line.unitSymbol,
                unitDecimalPlaces: line.unitDecimalPlaces,
                quantity: line.quantity,
                net: line.net,
                tax: line.tax,
                originalStockCost: costs[line.id],
              ),
          ],
        );
      case InvoiceKind.purchase:
        final invoice = (await _purchases.getById(invoiceId)).getOrThrow();
        return ReturnableInvoice(
          kind: kind,
          invoiceId: invoice.id,
          invoiceNumber: invoice.displayNumber,
          partyId: invoice.supplierId,
          partyName: invoice.supplierName,
          invoiceDate: invoice.invoiceDate,
          open: open,
          lines: [
            for (final line in invoice.lines)
              _line(
                prior,
                invoiceLineId: line.id,
                lineNo: line.lineNo,
                productId: line.productId,
                productName: line.productName,
                sku: line.sku,
                unitSymbol: line.unitSymbol,
                unitDecimalPlaces: line.unitDecimalPlaces,
                quantity: line.quantity,
                net: line.net,
                tax: line.tax,
              ),
          ],
        );
    }
  }

  /// Posted invoices of [kind] matching [query] (number or party name),
  /// newest first, for the "choose the invoice" step.
  Future<Result<List<InvoiceChoice>>> choices(
    InvoiceKind kind,
    String query,
  ) async {
    switch (kind) {
      case InvoiceKind.sales:
        return (await _sales.search(
          SalesFilter(query: query, status: DocumentStatus.posted),
        )).map(
          (list) => [
            for (final s in list)
              InvoiceChoice(
                kind: kind,
                id: s.id,
                number: s.number ?? '',
                partyName: s.customerName,
                invoiceDate: s.invoiceDate,
                total: s.total,
              ),
          ],
        );
      case InvoiceKind.purchase:
        return (await _purchases.search(
          PurchaseFilter(query: query, status: DocumentStatus.posted),
        )).map(
          (list) => [
            for (final s in list)
              InvoiceChoice(
                kind: kind,
                id: s.id,
                number: s.number ?? '',
                partyName: s.supplierName,
                invoiceDate: s.invoiceDate,
                total: s.total,
              ),
          ],
        );
    }
  }

  /// What each sold line cost when it left stock, by invoice line id.
  Future<Map<String, Money>> _saleCosts(SalesInvoice invoice) async {
    final movements = (await _inventory.movementsForSource(
      SalesNumbering.sourceType,
      invoice.id,
    )).getOrThrow();
    return {
      for (final m in movements)
        if (m.type == StockMovementType.sale && m.sourceLineId != null)
          m.sourceLineId!: m.totalCost.abs(),
    };
  }

  ReturnableLine _line(
    List<ReturnDocument> prior, {
    required String invoiceLineId,
    required int lineNo,
    required String productId,
    required String productName,
    required String sku,
    required String unitSymbol,
    required int unitDecimalPlaces,
    required Quantity quantity,
    required Money net,
    required Money tax,
    Money? originalStockCost,
  }) {
    var returnedQty = Quantity.zero;
    var restockedQty = Quantity.zero;
    var returnedNet = net - net;
    var returnedTax = tax - tax;
    var restockedCost = net - net;
    for (final doc in prior) {
      for (final line in doc.lines) {
        if (line.invoiceLineId != invoiceLineId) {
          continue;
        }
        returnedQty += line.quantity;
        returnedNet += line.net;
        returnedTax += line.tax;
        if (line.restocked && doc.kind == InvoiceKind.sales) {
          restockedQty += line.quantity;
          restockedCost += line.stockCost;
        }
      }
    }
    return ReturnableLine(
      invoiceLineId: invoiceLineId,
      lineNo: lineNo,
      productId: productId,
      productName: productName,
      sku: sku,
      unitSymbol: unitSymbol,
      unitDecimalPlaces: unitDecimalPlaces,
      quantity: quantity,
      net: net,
      tax: tax,
      returnedQuantity: returnedQty,
      returnedNet: returnedNet,
      returnedTax: returnedTax,
      restockedQuantity: restockedQty,
      restockedCost: restockedCost,
      originalStockCost: originalStockCost,
    );
  }
}
