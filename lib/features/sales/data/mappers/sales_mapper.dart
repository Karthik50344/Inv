import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/shared/domain/value_objects/line_amounts.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/features/sales/domain/entities/sales_summary.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// The currency an invoice was created in (its own snapshot, not the
/// current setting).
CurrencyConfig invoiceCurrency(SalesInvoiceRow row) => CurrencyConfig(
  currencyCode: row.currencyCode,
  decimalPlaces: row.decimalPlaces,
);

/// Header row + line rows -> entity.
SalesInvoice invoiceFromRows(
  SalesInvoiceRow row,
  List<SalesInvoiceItemRow> itemRows,
) {
  final currency = invoiceCurrency(row);
  final sorted = [...itemRows]..sort((a, b) => a.lineNo.compareTo(b.lineNo));
  return SalesInvoice(
    id: row.id,
    number: row.number,
    customerId: row.customerId,
    customerName: row.customerName,
    status: DocumentStatus.fromDbName(row.status),
    invoiceDate: fromEpochMs(row.invoiceDate),
    dueDate: fromEpochMsOrNull(row.dueDate),
    customerReference: row.customerReference,
    notes: row.notes,
    lines: [for (final item in sorted) lineFromRow(item, currency)],
    totals: SalesTotals(
      gross: currency.fromMinor(row.subtotalMinor),
      discount: currency.fromMinor(row.discountTotalMinor),
      net: currency.fromMinor(row.netTotalMinor),
      tax: currency.fromMinor(row.taxTotalMinor),
      total: currency.fromMinor(row.totalMinor),
    ),
    createdAt: fromEpochMs(row.createdAt),
    updatedAt: fromEpochMs(row.updatedAt),
    postedAt: fromEpochMsOrNull(row.postedAt),
    cancelledAt: fromEpochMsOrNull(row.cancelledAt),
    voidedAt: fromEpochMsOrNull(row.voidedAt),
    voidReason: row.voidReason,
  );
}

/// Line row -> entity.
SalesLine lineFromRow(SalesInvoiceItemRow row, CurrencyConfig currency) =>
    SalesLine(
      id: row.id,
      lineNo: row.lineNo,
      productId: row.productId,
      productName: row.productName,
      sku: row.sku,
      unitSymbol: row.unitSymbol,
      unitDecimalPlaces: row.unitDecimalPlaces,
      quantity: Quantity.fromMilli(row.quantityMilli),
      unitPrice: currency.fromMinor(row.unitPriceMinor),
      priceIncludesTax: row.priceIncludesTax,
      discount: Discount.fromStored(
        DiscountKind.fromDbName(row.discountType),
        row.discountValue,
        money: currency.fromMinor,
      ),
      taxRateBp: row.taxRateBp,
      taxName: row.taxName,
      amounts: LineAmounts(
        gross: currency.fromMinor(row.grossMinor),
        discount: currency.fromMinor(row.discountMinor),
        net: currency.fromMinor(row.netMinor),
        tax: currency.fromMinor(row.taxMinor),
        total: currency.fromMinor(row.totalMinor),
      ),
    );

/// Entity -> header insert/update companion.
SalesInvoicesCompanion invoiceToCompanion(SalesInvoice invoice) {
  final total = invoice.totals.total;
  return SalesInvoicesCompanion(
    id: Value(invoice.id),
    number: Value(invoice.number),
    customerId: Value(invoice.customerId),
    customerName: Value(invoice.customerName),
    status: Value(invoice.status.dbName),
    invoiceDate: Value(toEpochMs(invoice.invoiceDate)),
    dueDate: Value(toEpochMsOrNull(invoice.dueDate)),
    customerReference: Value(invoice.customerReference),
    notes: Value(invoice.notes),
    currencyCode: Value(total.currencyCode),
    decimalPlaces: Value(total.decimalPlaces),
    subtotalMinor: Value(invoice.totals.gross.minorUnits),
    discountTotalMinor: Value(invoice.totals.discount.minorUnits),
    netTotalMinor: Value(invoice.totals.net.minorUnits),
    taxTotalMinor: Value(invoice.totals.tax.minorUnits),
    totalMinor: Value(total.minorUnits),
    postedAt: Value(toEpochMsOrNull(invoice.postedAt)),
    cancelledAt: Value(toEpochMsOrNull(invoice.cancelledAt)),
    voidedAt: Value(toEpochMsOrNull(invoice.voidedAt)),
    voidReason: Value(invoice.voidReason),
    createdAt: Value(toEpochMs(invoice.createdAt)),
    updatedAt: Value(toEpochMs(invoice.updatedAt)),
  );
}

/// Entity line -> insert companion.
SalesInvoiceItemsCompanion lineToCompanion(
  SalesLine line,
  String invoiceId,
) => SalesInvoiceItemsCompanion(
  id: Value(line.id),
  invoiceId: Value(invoiceId),
  lineNo: Value(line.lineNo),
  productId: Value(line.productId),
  productName: Value(line.productName),
  sku: Value(line.sku),
  unitSymbol: Value(line.unitSymbol),
  unitDecimalPlaces: Value(line.unitDecimalPlaces),
  quantityMilli: Value(line.quantity.milli),
  unitPriceMinor: Value(line.unitPrice.minorUnits),
  priceIncludesTax: Value(line.priceIncludesTax),
  discountType: Value(line.discount.kind.dbName),
  discountValue: Value(line.discount.storedValue),
  taxRateBp: Value(line.taxRateBp),
  taxName: Value(line.taxName),
  grossMinor: Value(line.gross.minorUnits),
  discountMinor: Value(line.discountAmount.minorUnits),
  netMinor: Value(line.net.minorUnits),
  taxMinor: Value(line.tax.minorUnits),
  totalMinor: Value(line.total.minorUnits),
);

/// A list query row -> summary.
SalesSummary summaryFromRow(QueryRow row) {
  final currency = CurrencyConfig(
    currencyCode: row.read<String>('currency_code'),
    decimalPlaces: row.read<int>('decimal_places'),
  );
  return SalesSummary(
    id: row.read<String>('id'),
    number: row.readNullable<String>('number'),
    customerId: row.readNullable<String>('customer_id'),
    customerName: row.read<String>('customer_name'),
    status: DocumentStatus.fromDbName(row.read<String>('status')),
    invoiceDate: fromEpochMs(row.read<int>('invoice_date')),
    dueDate: fromEpochMsOrNull(row.readNullable<int>('due_date')),
    customerReference: row.readNullable<String>('customer_reference'),
    total: currency.fromMinor(row.read<int>('total_minor')),
    lineCount: row.read<int>('line_count'),
  );
}
