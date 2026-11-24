import 'package:equatable/equatable.dart';

/// How the export is delivered.
enum ExportFormat {
  /// CSV: one `.csv` when a single table is exported, otherwise a ZIP of
  /// CSV files with a manifest and checksums.
  csv('csv', 'CSV'),

  /// One Excel workbook with a sheet per table.
  xlsx('xlsx', 'Excel (XLSX)'),

  /// A PDF report: summaries, tax and HSN/SAC totals, integrity result. It
  /// does not hold every ledger row; use CSV, XLSX or ZIP for that.
  pdf('pdf', 'PDF report'),

  /// The complete read-only auditor package (CSV files, manifest,
  /// checksums, PDFs, attachments).
  zip('zip', 'Complete ZIP package');

  const ExportFormat(this.code, this.label);

  /// Stable storage code.
  final String code;

  /// Name shown to users.
  final String label;

  /// The format stored as [code]; unknown codes become [zip].
  static ExportFormat parse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return zip;
  }
}

/// How the period was chosen.
enum ExportPeriodKind {
  /// A financial year.
  financialYear('financial_year'),

  /// A custom date range.
  custom('custom'),

  /// Everything available.
  all('all');

  const ExportPeriodKind(this.code);

  /// Stable storage code.
  final String code;

  /// The kind stored as [code]; unknown codes become [all].
  static ExportPeriodKind parse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return all;
  }
}

/// The date range an export covers. Both ends are calendar dates and
/// inclusive; `null` ends mean unbounded.
final class ExportPeriod extends Equatable {
  const ExportPeriod._(this.kind, this.from, this.to, this.label);

  /// Every record, whatever its date.
  const ExportPeriod.all() : this._(ExportPeriodKind.all, null, null, 'All dates');

  /// A custom range from [from] to [to] (inclusive).
  factory ExportPeriod.custom(DateTime from, DateTime to) => ExportPeriod._(
    ExportPeriodKind.custom,
    _day(from),
    _day(to),
    '${_iso(_day(from))} to ${_iso(_day(to))}',
  );

  /// The financial year that starts on day 1 of [startMonth] in
  /// [startYear] (April by default, as in India) and ends the day before
  /// the same date a year later.
  factory ExportPeriod.financialYear(int startYear, {int startMonth = 4}) {
    final from = DateTime.utc(startYear, startMonth);
    final to = DateTime.utc(startYear + 1, startMonth).subtract(
      const Duration(days: 1),
    );
    final label = startMonth == 1
        ? 'Calendar year $startYear'
        : 'FY $startYear-${((startYear + 1) % 100).toString().padLeft(2, '0')}';
    return ExportPeriod._(ExportPeriodKind.financialYear, from, to, label);
  }

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// How it was chosen.
  final ExportPeriodKind kind;

  /// First day (UTC date), or `null`.
  final DateTime? from;

  /// Last day (UTC date, inclusive), or `null`.
  final DateTime? to;

  /// Name shown to users and written to the manifest.
  final String label;

  /// First millisecond of the period, or `null`.
  int? get fromMs => from?.millisecondsSinceEpoch;

  /// Last millisecond of the period, or `null`.
  int? get toMsInclusive => to == null
      ? null
      : to!.add(const Duration(days: 1)).millisecondsSinceEpoch - 1;

  /// Whether the range is usable.
  bool get isValid => from == null || to == null || !from!.isAfter(to!);

  /// `yyyy-MM-dd` of [from], or `null`.
  String? get fromText => from == null ? null : _iso(from!);

  /// `yyyy-MM-dd` of [to], or `null`.
  String? get toText => to == null ? null : _iso(to!);

  @override
  List<Object?> get props => [kind, from, to, label];
}

/// A selectable group of records. Each dataset becomes one or more files.
enum ExportDataset {
  /// The business profile.
  businessProfile('business_profile', 'Business profile', 'business_profile', false),

  /// Products.
  products('products', 'Products', 'master_data', false),

  /// Product classifications (HSN/SAC/HS).
  productClassifications('product_classifications', 'Product classifications', 'master_data', false),

  /// Customers.
  customers('customers', 'Customers', 'master_data', false),

  /// Suppliers.
  suppliers('suppliers', 'Suppliers', 'master_data', false),

  /// Sales invoices and their lines.
  salesInvoices('sales_invoices', 'Sales invoices', 'sales', true),

  /// Sales returns and their lines.
  salesReturns('sales_returns', 'Sales returns', 'sales', true),

  /// Purchase invoices and their lines.
  purchaseInvoices('purchase_invoices', 'Purchase invoices', 'purchases', true),

  /// Purchase returns and their lines.
  purchaseReturns('purchase_returns', 'Purchase returns', 'purchases', true),

  /// Payments, allocations and reversals.
  payments('payments', 'Payments and allocations', 'payments', true),

  /// Expenses.
  expenses('expenses', 'Expenses', 'expenses', true),

  /// Current stock quantities and valuation.
  inventoryBalances('inventory_balances', 'Inventory balances', 'inventory', false),

  /// Every stock movement.
  stockMovements('stock_movements', 'Stock movement ledger', 'inventory', true),

  /// Tax regimes, rules and components.
  taxConfigurations('tax_configurations', 'Tax rules and configuration', 'taxation', false),

  /// Tax totals by component and treatment.
  taxSummaries('tax_summaries', 'Tax summaries', 'taxation', true),

  /// Totals by HSN/SAC/classification code.
  hsnSummaries('hsn_summaries', 'HSN/SAC summaries', 'taxation', true),

  /// The audit trail and its integrity report.
  auditTrail('audit_trail', 'Audit trail', 'audit', true),

  /// Expense attachment files.
  attachments('attachments', 'Attachments', 'documents', true),

  /// A PDF of every sales invoice in the period.
  invoicePdfs('invoice_pdfs', 'Invoice PDFs', 'documents', true);

  const ExportDataset(this.code, this.label, this.folder, this.usesPeriod);

  /// Stable storage code.
  final String code;

  /// Name shown to users.
  final String label;

  /// Folder inside the package.
  final String folder;

  /// Whether the export period filters this dataset. Master data and
  /// current balances are always exported as they are at export time.
  final bool usesPeriod;

  /// The dataset stored as [code], or `null`.
  static ExportDataset? tryParse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return null;
  }
}

/// What the user asked for.
final class ExportRequest extends Equatable {
  /// Creates a request.
  const ExportRequest({
    required this.period,
    required this.datasets,
    required this.format,
    this.name,
  });

  /// Date range.
  final ExportPeriod period;

  /// What to include.
  final Set<ExportDataset> datasets;

  /// How to deliver it.
  final ExportFormat format;

  /// Optional name chosen by the user.
  final String? name;

  /// The datasets in a stable order.
  List<ExportDataset> get orderedDatasets =>
      ExportDataset.values.where(datasets.contains).toList();

  @override
  List<Object?> get props => [period, datasets, format, name];
}
