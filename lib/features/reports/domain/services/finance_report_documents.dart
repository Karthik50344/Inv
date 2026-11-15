import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/payments/domain/entities/party_balance.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/services/profit_calculator.dart';
import 'package:inventrix/features/reports/domain/services/report_text.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Builds the product performance, payment, expense, profitability and
/// outstanding-balance reports.
abstract final class FinanceReportDocuments {
  /// Units sold, revenue, cost and gross profit per product.
  static ReportDocument productPerformance({
    required ReportFilter filter,
    required DateTime generatedAt,
    required List<String> scope,
    required List<ProductFigures> products,
    required Money zero,
  }) {
    var revenue = zero;
    var cost = zero;
    for (final p in products) {
      revenue += p.netRevenue;
      cost += p.cost;
    }
    final profit = revenue - cost;
    final margin = ProfitFigures(
      netSales: revenue,
      costOfGoodsSold: cost,
      expenses: zero,
    ).grossMarginBasisPoints;
    return ReportDocument(
      kind: ReportKind.productPerformance.name,
      title: ReportKind.productPerformance.title,
      generatedAt: generatedAt,
      periodText: ReportText.period(filter.range),
      scope: scope,
      metrics: [
        ReportMetric('Products sold', CountCell(products.length)),
        ReportMetric('Net revenue (excl. tax)', MoneyCell(revenue)),
        ReportMetric('Cost of goods sold', MoneyCell(cost)),
        ReportMetric('Gross profit', MoneyCell(profit)),
        ReportMetric(
          'Gross margin',
          margin == null ? const EmptyCell() : PercentCell(margin),
        ),
      ],
      tables: [
        ReportTable(
          title: 'Products by net revenue',
          columns: const [
            ReportColumn('Product'),
            ReportColumn('SKU'),
            ReportColumn('Units sold', numeric: true),
            ReportColumn('Net revenue', numeric: true),
            ReportColumn('Cost', numeric: true),
            ReportColumn('Gross profit', numeric: true),
            ReportColumn('Margin', numeric: true),
          ],
          rows: [
            for (final p in products)
              [
                TextCell(p.name),
                TextCell(p.sku),
                QuantityCell(
                  p.netQuantity,
                  decimals: p.unitDecimalPlaces,
                  unit: p.unitSymbol,
                ),
                MoneyCell(p.netRevenue),
                MoneyCell(p.cost),
                MoneyCell(p.grossProfit),
                p.marginBasisPoints == null
                    ? const EmptyCell()
                    : PercentCell(p.marginBasisPoints!),
              ],
          ],
        ),
      ],
      notes: const [
        'Units and revenue are posted sales minus sales returns, excluding '
            'tax.',
        'Cost comes from the stock ledger at the weighted average cost when '
            'the goods were sold; goods returned into stock reduce it.',
        'Margin is gross profit as a percentage of net revenue.',
      ],
    );
  }

  /// Cash received and paid, kept apart from sales revenue.
  static ReportDocument payments({
    required ReportFilter filter,
    required DateTime generatedAt,
    required List<String> scope,
    required CashFigures cash,
  }) {
    final otherNote = ReportText.otherCurrencyNote(cash.otherCurrencyCount);
    return ReportDocument(
      kind: ReportKind.payments.name,
      title: ReportKind.payments.title,
      generatedAt: generatedAt,
      periodText: ReportText.period(filter.range),
      scope: scope,
      metrics: [
        ReportMetric('Cash received', MoneyCell(cash.cashIn)),
        ReportMetric('Cash paid out', MoneyCell(cash.cashOut)),
        ReportMetric('Net cash', MoneyCell(cash.net)),
        ReportMetric('Entries', CountCell(cash.entryCount)),
      ],
      tables: [
        ReportTable(
          title: 'Cash by type',
          columns: const [
            ReportColumn('Type'),
            ReportColumn('Direction'),
            ReportColumn('Amount', numeric: true),
          ],
          rows: [
            _cashRow('Payments from customers', 'In', cash.customerPayments),
            _cashRow('Refunds from suppliers', 'In', cash.supplierRefunds),
            _cashRow(
              'Cash back on purchase returns',
              'In',
              cash.purchaseReturnRefunds,
            ),
            _cashRow('Payments to suppliers', 'Out', cash.supplierPayments),
            _cashRow('Refunds to customers', 'Out', cash.customerRefunds),
            _cashRow(
              'Cash back on sales returns',
              'Out',
              cash.salesReturnRefunds,
            ),
          ],
        ),
        ReportTable(
          title: 'Cash by payment method',
          columns: const [
            ReportColumn('Method'),
            ReportColumn('In', numeric: true),
            ReportColumn('Out', numeric: true),
            ReportColumn('Net', numeric: true),
          ],
          rows: [
            for (final m in cash.byMethod)
              [
                TextCell(m.methodName),
                MoneyCell(m.moneyIn),
                MoneyCell(m.moneyOut),
                MoneyCell(m.net),
              ],
          ],
        ),
      ],
      notes: [
        'Cash is not revenue: a sale counts as revenue when it is posted, '
            'whatever the customer has paid so far.',
        'Reversed payments are left out because they never took effect.',
        'Payments are counted on their payment date. Expenses are not '
            'included; see the expense report.',
        ?otherNote,
      ],
    );
  }

  static List<ReportCell> _cashRow(String label, String direction, Money m) => [
    TextCell(label),
    TextCell(direction),
    MoneyCell(m),
  ];

  /// Posted expenses by category.
  static ReportDocument expenses({
    required ReportFilter filter,
    required DateTime generatedAt,
    required ExpenseReport report,
  }) {
    final otherNote = ReportText.otherCurrencyNote(report.otherCurrencyCount);
    return ReportDocument(
      kind: ReportKind.expenses.name,
      title: ReportKind.expenses.title,
      generatedAt: generatedAt,
      periodText: ReportText.period(filter.range),
      metrics: [
        ReportMetric('Expenses', CountCell(report.count)),
        ReportMetric('Amount excl. tax', MoneyCell(report.net)),
        ReportMetric('Tax', MoneyCell(report.tax)),
        ReportMetric('Total paid', MoneyCell(report.total)),
      ],
      tables: [
        ReportTable(
          title: 'By category',
          columns: const [
            ReportColumn('Category'),
            ReportColumn('Count', numeric: true),
            ReportColumn('Net', numeric: true),
            ReportColumn('Tax', numeric: true),
            ReportColumn('Total', numeric: true),
          ],
          rows: [
            for (final c in report.byCategory)
              [
                TextCell(c.categoryName),
                CountCell(c.count),
                MoneyCell(c.net),
                MoneyCell(c.tax),
                MoneyCell(c.total),
              ],
          ],
        ),
      ],
      notes: [
        'Only posted expenses count, on their expense date.',
        'Total paid includes tax; the profitability report uses the amount '
            'excluding tax.',
        ?otherNote,
      ],
    );
  }

  /// Net sales, cost of goods sold, expenses and the operating result.
  static ReportDocument profitability({
    required ReportFilter filter,
    required DateTime generatedAt,
    required DocumentFigures sales,
    required ProfitFigures profit,
    required int expenseCount,
  }) {
    final grossMargin = profit.grossMarginBasisPoints;
    final operatingMargin = profit.operatingMarginBasisPoints;
    final otherNote = ReportText.otherCurrencyNote(sales.otherCurrencyCount);
    return ReportDocument(
      kind: ReportKind.profitability.name,
      title: ReportKind.profitability.title,
      generatedAt: generatedAt,
      periodText: ReportText.period(filter.range),
      metrics: [
        ReportMetric('Net sales', MoneyCell(profit.netSales)),
        ReportMetric('Gross profit', MoneyCell(profit.grossProfit)),
        ReportMetric(
          'Gross margin',
          grossMargin == null ? const EmptyCell() : PercentCell(grossMargin),
        ),
        ReportMetric(
          'Operating result',
          MoneyCell(profit.operatingResult),
          hint: 'Estimate',
        ),
        ReportMetric(
          'Operating margin',
          operatingMargin == null
              ? const EmptyCell()
              : PercentCell(operatingMargin),
        ),
      ],
      tables: [
        ReportTable(
          title: 'Profit and loss estimate',
          columns: const [
            ReportColumn('Line'),
            ReportColumn('Amount', numeric: true),
          ],
          rows: [
            [const TextCell('Sales (excl. tax)'), MoneyCell(sales.net)],
            [
              const TextCell('Less: sales returns'),
              MoneyCell(sales.returnsNet),
            ],
            [const TextCell('Net sales'), MoneyCell(profit.netSales)],
            [
              const TextCell('Less: cost of goods sold'),
              MoneyCell(profit.costOfGoodsSold),
            ],
            [const TextCell('Gross profit'), MoneyCell(profit.grossProfit)],
            [
              TextCell('Less: operating expenses ($expenseCount)'),
              MoneyCell(profit.expenses),
            ],
            [
              const TextCell('Operating result'),
              MoneyCell(profit.operatingResult),
            ],
          ],
        ),
      ],
      notes: [
        'This is an estimate for management use, not an accounting '
            'statement.',
        'Revenue is net sales: posted sales minus sales returns, excluding '
            'sales tax, on the invoice and return dates.',
        'Cost of goods sold is read from the stock ledger at weighted '
            'average cost; goods put back into stock reduce it, goods '
            'written off do not.',
        'Purchases are not an expense: stock is an asset until it is sold.',
        'Operating expenses are posted expenses excluding tax, on the '
            'expense date. Tax on expenses is assumed to be recoverable.',
        'Cash received is not revenue and cash paid is not cost; see the '
            'payment report.',
        ?otherNote,
      ],
    );
  }

  /// Who owes us (customers) or whom we owe (suppliers).
  static ReportDocument outstanding({
    required PartyType type,
    required DateTime generatedAt,
    required List<PartyBalance> balances,
    required Money zero,
  }) {
    final isCustomer = type == PartyType.customer;
    final kind = isCustomer
        ? ReportKind.customerOutstanding
        : ReportKind.supplierOutstanding;
    var owed = zero;
    var credit = zero;
    for (final b in balances) {
      if (b.balance.isPositive) {
        owed += b.balance;
      } else if (b.balance.isNegative) {
        credit += b.balance.abs();
      }
    }
    return ReportDocument(
      kind: kind.name,
      title: kind.title,
      generatedAt: generatedAt,
      metrics: [
        ReportMetric(
          isCustomer ? 'Customers owing' : 'Suppliers owed',
          CountCell(balances.where((b) => b.balance.isPositive).length),
        ),
        ReportMetric(
          isCustomer ? 'Total receivable' : 'Total payable',
          MoneyCell(owed),
        ),
        ReportMetric('Credit balances', MoneyCell(credit)),
      ],
      tables: [
        ReportTable(
          title: isCustomer ? 'Customer balances' : 'Supplier balances',
          columns: [
            ReportColumn(isCustomer ? 'Customer' : 'Supplier'),
            const ReportColumn('Opening', numeric: true),
            const ReportColumn('Invoiced', numeric: true),
            const ReportColumn('Returns', numeric: true),
            const ReportColumn('Payments', numeric: true),
            const ReportColumn('Refunds', numeric: true),
            const ReportColumn('Balance', numeric: true),
          ],
          rows: [
            for (final b in balances)
              [
                TextCell(b.partyName),
                MoneyCell(b.opening),
                MoneyCell(b.invoiced),
                MoneyCell(b.returns),
                MoneyCell(b.payments),
                MoneyCell(b.refunds + b.returnRefunds),
                MoneyCell(b.balance),
              ],
          ],
        ),
      ],
      notes: [
        'Balance = opening balance + posted invoices - returns - active '
            'payments + refunds. A negative balance is credit.',
        'Parties with a zero balance are not listed; archived parties are '
            'included while a balance remains.',
        'Total ${isCustomer ? 'receivable' : 'payable'} adds up positive '
            'balances only; credit balances are shown separately.',
      ],
    );
  }
}
