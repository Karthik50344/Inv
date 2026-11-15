import 'package:equatable/equatable.dart';
import 'package:inventrix/core/utils/rounding.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Totals of posted sales (or purchases) and of their returns in a period.
///
/// Voided and cancelled documents are not counted. Only documents in the
/// configured currency are added up; the others are counted in
/// [otherCurrencyCount] so nothing disappears silently.
final class DocumentFigures extends Equatable {
  /// Creates figures.
  const DocumentFigures({
    required this.count,
    required this.net,
    required this.tax,
    required this.total,
    required this.returnsCount,
    required this.returnsNet,
    required this.returnsTax,
    required this.returnsTotal,
    this.otherCurrencyCount = 0,
  });

  /// Zero figures in the currency of [zero].
  factory DocumentFigures.empty(Money zero) => DocumentFigures(
    count: 0,
    net: zero,
    tax: zero,
    total: zero,
    returnsCount: 0,
    returnsNet: zero,
    returnsTax: zero,
    returnsTotal: zero,
  );

  /// Number of posted documents.
  final int count;

  /// Amount excluding tax, before returns.
  final Money net;

  /// Tax on the documents.
  final Money tax;

  /// Amount including tax, before returns.
  final Money total;

  /// Number of returns posted in the period.
  final int returnsCount;

  /// Returned amount excluding tax.
  final Money returnsNet;

  /// Tax on the returns.
  final Money returnsTax;

  /// Returned amount including tax.
  final Money returnsTotal;

  /// Documents and returns left out because of another currency.
  final int otherCurrencyCount;

  /// [net] minus [returnsNet]: the figure used for revenue and profit.
  Money get netAfterReturns => net - returnsNet;

  /// [total] minus [returnsTotal].
  Money get totalAfterReturns => total - returnsTotal;

  /// Whether nothing happened in the period.
  bool get isEmpty => count == 0 && returnsCount == 0;

  @override
  List<Object?> get props => [
    count,
    net,
    tax,
    total,
    returnsCount,
    returnsNet,
    returnsTax,
    returnsTotal,
    otherCurrencyCount,
  ];
}

/// One posted invoice as a line of a register.
final class DocumentRow extends Equatable {
  /// Creates a row.
  const DocumentRow({
    required this.id,
    required this.number,
    required this.date,
    required this.partyName,
    required this.net,
    required this.tax,
    required this.total,
  });

  /// Document id.
  final String id;

  /// Document number.
  final String number;

  /// Document date (date only, UTC).
  final DateTime date;

  /// Customer or supplier name as recorded on the document.
  final String partyName;

  /// Amount excluding tax.
  final Money net;

  /// Tax.
  final Money tax;

  /// Amount including tax.
  final Money total;

  @override
  List<Object?> get props => [id, number, date, partyName, net, tax, total];
}

/// An amount on one day (for charts).
final class DatedAmount extends Equatable {
  /// Creates an entry.
  const DatedAmount(this.date, this.amount);

  /// The day (date only, UTC).
  final DateTime date;

  /// The amount.
  final Money amount;

  @override
  List<Object?> get props => [date, amount];
}

/// Documents and returns per day.
final class DailySeries extends Equatable {
  /// Creates a series.
  const DailySeries({required this.documents, required this.returns});

  /// Net amounts of posted documents per day.
  final List<DatedAmount> documents;

  /// Net amounts of returns per day.
  final List<DatedAmount> returns;

  @override
  List<Object?> get props => [documents, returns];
}

/// Sales of one product in a period.
///
/// All amounts exclude tax. [cost] is the cost of the goods that were
/// sold and not taken back into stock, read from the stock ledger.
final class ProductFigures extends Equatable {
  /// Creates figures.
  const ProductFigures({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unitSymbol,
    required this.unitDecimalPlaces,
    required this.quantitySold,
    required this.quantityReturned,
    required this.revenue,
    required this.returnedRevenue,
    required this.cost,
  });

  /// Product id.
  final String productId;

  /// Product name as recorded on the invoices.
  final String name;

  /// SKU as recorded on the invoices.
  final String sku;

  /// Unit symbol.
  final String unitSymbol;

  /// Decimals the unit allows.
  final int unitDecimalPlaces;

  /// Quantity on posted invoices.
  final Quantity quantitySold;

  /// Quantity returned.
  final Quantity quantityReturned;

  /// Invoiced amount.
  final Money revenue;

  /// Returned amount.
  final Money returnedRevenue;

  /// Cost of goods sold, net of goods put back into stock.
  final Money cost;

  /// Units sold minus units returned.
  Quantity get netQuantity =>
      Quantity.fromMilli(quantitySold.milli - quantityReturned.milli);

  /// Revenue minus returns.
  Money get netRevenue => revenue - returnedRevenue;

  /// [netRevenue] minus [cost].
  Money get grossProfit => netRevenue - cost;

  /// Gross margin in basis points of [netRevenue]; `null` without revenue.
  int? get marginBasisPoints => netRevenue.isPositive
      ? roundedMulDiv(grossProfit.minorUnits, 10000, netRevenue.minorUnits)
      : null;

  @override
  List<Object?> get props => [
    productId,
    name,
    sku,
    unitSymbol,
    unitDecimalPlaces,
    quantitySold,
    quantityReturned,
    revenue,
    returnedRevenue,
    cost,
  ];
}

/// Cash received and paid in a period by payment method.
final class MethodCash extends Equatable {
  /// Creates an entry.
  const MethodCash({
    required this.methodId,
    required this.methodName,
    required this.moneyIn,
    required this.moneyOut,
  });

  /// Payment method id.
  final String methodId;

  /// Method name as recorded.
  final String methodName;

  /// Cash received through this method.
  final Money moneyIn;

  /// Cash paid out through this method.
  final Money moneyOut;

  /// [moneyIn] minus [moneyOut].
  Money get net => moneyIn - moneyOut;

  @override
  List<Object?> get props => [methodId, methodName, moneyIn, moneyOut];
}

/// Cash movements with customers and suppliers in a period.
///
/// Only active payments count (a reversed payment never happened). Cash is
/// kept apart from revenue: a sale is revenue when it is posted, whatever
/// the customer has paid.
final class CashFigures extends Equatable {
  /// Creates figures.
  const CashFigures({
    required this.customerPayments,
    required this.customerRefunds,
    required this.supplierPayments,
    required this.supplierRefunds,
    required this.salesReturnRefunds,
    required this.purchaseReturnRefunds,
    required this.entryCount,
    required this.byMethod,
    this.otherCurrencyCount = 0,
  });

  /// Zero figures in the currency of [zero].
  factory CashFigures.empty(Money zero) => CashFigures(
    customerPayments: zero,
    customerRefunds: zero,
    supplierPayments: zero,
    supplierRefunds: zero,
    salesReturnRefunds: zero,
    purchaseReturnRefunds: zero,
    entryCount: 0,
    byMethod: const [],
  );

  /// Received from customers.
  final Money customerPayments;

  /// Given back to customers through refund records.
  final Money customerRefunds;

  /// Paid to suppliers.
  final Money supplierPayments;

  /// Received back from suppliers through refund records.
  final Money supplierRefunds;

  /// Given back to customers at the moment of a sales return.
  final Money salesReturnRefunds;

  /// Received from suppliers at the moment of a purchase return.
  final Money purchaseReturnRefunds;

  /// Number of cash entries counted.
  final int entryCount;

  /// Cash per payment method, largest turnover first.
  final List<MethodCash> byMethod;

  /// Entries left out because of another currency.
  final int otherCurrencyCount;

  /// All cash received.
  Money get cashIn =>
      customerPayments + supplierRefunds + purchaseReturnRefunds;

  /// All cash paid out.
  Money get cashOut => supplierPayments + customerRefunds + salesReturnRefunds;

  /// [cashIn] minus [cashOut].
  Money get net => cashIn - cashOut;

  @override
  List<Object?> get props => [
    customerPayments,
    customerRefunds,
    supplierPayments,
    supplierRefunds,
    salesReturnRefunds,
    purchaseReturnRefunds,
    entryCount,
    byMethod,
    otherCurrencyCount,
  ];
}

/// One stock ledger entry in the movement report.
final class MovementRow extends Equatable {
  /// Creates a row.
  const MovementRow({
    required this.id,
    required this.occurredAt,
    required this.productName,
    required this.sku,
    required this.type,
    required this.quantity,
    required this.unitDecimalPlaces,
    required this.unitSymbol,
    required this.value,
    this.reason,
  });

  /// Ledger entry id.
  final String id;

  /// When the stock changed.
  final DateTime occurredAt;

  /// Product name.
  final String productName;

  /// Product SKU.
  final String sku;

  /// Kind of movement.
  final StockMovementType type;

  /// Signed quantity (negative = stock out).
  final Quantity quantity;

  /// Decimals of the unit.
  final int unitDecimalPlaces;

  /// Unit symbol.
  final String unitSymbol;

  /// Signed value (same sign as the quantity).
  final Money value;

  /// Reason, when one was given.
  final String? reason;

  @override
  List<Object?> get props => [
    id,
    occurredAt,
    productName,
    sku,
    type,
    quantity,
    unitDecimalPlaces,
    unitSymbol,
    value,
    reason,
  ];
}

/// The stock ledger in a period.
final class MovementReportData extends Equatable {
  /// Creates the data.
  const MovementReportData({
    required this.rows,
    required this.totalCount,
    required this.valueIn,
    required this.valueOut,
  });

  /// The newest entries (at most the requested limit).
  final List<MovementRow> rows;

  /// Number of entries in the period, whether returned or not.
  final int totalCount;

  /// Value of all stock-in entries.
  final Money valueIn;

  /// Value of all stock-out entries (positive number).
  final Money valueOut;

  /// Whether [rows] is shorter than the period's entries.
  bool get isTruncated => rows.length < totalCount;

  @override
  List<Object?> get props => [rows, totalCount, valueIn, valueOut];
}
