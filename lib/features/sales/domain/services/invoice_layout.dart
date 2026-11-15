import 'package:equatable/equatable.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A label/value pair printed on an invoice.
final class InvoiceField extends Equatable {
  /// Creates a field.
  const InvoiceField(this.label, this.value);

  /// Left text.
  final String label;

  /// Right text.
  final String value;

  @override
  List<Object?> get props => [label, value];
}

/// Everything printed on an invoice as plain text, in print order.
///
/// The PDF renderer only lays this out, so the printed document and the
/// stored invoice cannot drift apart, and the content can be tested without
/// a PDF library.
final class InvoiceLayout extends Equatable {
  /// Creates a layout.
  const InvoiceLayout({
    required this.title,
    required this.businessName,
    required this.businessLines,
    required this.meta,
    required this.columns,
    required this.rows,
    required this.totals,
    required this.grandTotal,
    required this.fileName,
    this.statusNote,
    this.notes,
  });

  /// Builds the layout of [invoice]. [money] and [date] format values for
  /// display; money must not rely on glyphs outside basic Latin because the
  /// built-in PDF fonts lack them (use the currency code, not a symbol).
  factory InvoiceLayout.from(
    SalesInvoice invoice,
    BusinessProfile business, {
    required String Function(Money) money,
    required String Function(DateTime) date,
  }) {
    String percent(int bp) {
      final whole = bp ~/ 100;
      final fraction = bp % 100;
      if (fraction == 0) {
        return '$whole%';
      }
      final text = fraction
          .toString()
          .padLeft(2, '0')
          .replaceAll(
            RegExp(r'0+$'),
            '',
          );
      return '$whole.$text%';
    }

    final rows = <List<String>>[
      for (final line in invoice.lines)
        [
          '${line.lineNo}',
          line.sku.isEmpty
              ? line.productName
              : '${line.productName}\n${line.sku}',
          '${line.quantity.toDecimalString()} ${line.unitSymbol}',
          line.priceIncludesTax
              ? '${money(line.unitPrice)} (incl. tax)'
              : money(line.unitPrice),
          line.discountAmount.isPositive ? money(line.discountAmount) : '-',
          line.taxRateBp == 0
              ? '-'
              : '${percent(line.taxRateBp)} ${money(line.tax)}',
          money(line.total),
        ],
    ];
    final number = invoice.number;
    final status = invoice.status;
    final due = invoice.dueDate;
    final reference = invoice.customerReference;
    final voidReason = invoice.voidReason;
    return InvoiceLayout(
      title: status == DocumentStatus.posted || status == DocumentStatus.voided
          ? 'TAX INVOICE'
          : 'DRAFT INVOICE',
      businessName: business.name,
      businessLines: [
        if (business.address != null) ...business.address!.split('\n'),
        if (business.phone != null) 'Phone: ${business.phone}',
        if (business.email != null) 'Email: ${business.email}',
        if (business.taxId != null) 'Tax ID: ${business.taxId}',
      ],
      meta: [
        InvoiceField('Invoice no.', number ?? 'Draft'),
        InvoiceField('Date', date(invoice.invoiceDate)),
        if (due != null) InvoiceField('Due date', date(due)),
        InvoiceField('Bill to', invoice.customerName),
        if (reference != null) InvoiceField('Reference', reference),
      ],
      columns: const [
        '#',
        'Item',
        'Qty',
        'Rate',
        'Discount',
        'Tax',
        'Amount',
      ],
      rows: rows,
      totals: [
        InvoiceField('Subtotal', money(invoice.totals.gross)),
        if (invoice.totals.discount.isPositive)
          InvoiceField('Discount', '- ${money(invoice.totals.discount)}'),
        InvoiceField('Tax', money(invoice.totals.tax)),
      ],
      grandTotal: InvoiceField('Total', money(invoice.totals.total)),
      statusNote: status == DocumentStatus.voided
          ? 'VOID${voidReason == null ? '' : ': $voidReason'}'
          : null,
      notes: invoice.notes,
      fileName: _fileName(invoice),
    );
  }

  static String _fileName(SalesInvoice invoice) {
    final base = (invoice.number ?? 'draft-${invoice.id}').replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    return '$base.pdf';
  }

  /// Document title.
  final String title;

  /// Business name (large).
  final String businessName;

  /// Address and contact lines under the name.
  final List<String> businessLines;

  /// Invoice number, date, customer, ...
  final List<InvoiceField> meta;

  /// Column headings of the item table.
  final List<String> columns;

  /// One entry per invoice line, one string per column.
  final List<List<String>> rows;

  /// Subtotal, discount and tax rows.
  final List<InvoiceField> totals;

  /// The amount due.
  final InvoiceField grandTotal;

  /// Banner for voided invoices.
  final String? statusNote;

  /// Free-text notes.
  final String? notes;

  /// Suggested file name, for example `INV-000001.pdf`.
  final String fileName;

  @override
  List<Object?> get props => [
    title,
    businessName,
    businessLines,
    meta,
    columns,
    rows,
    totals,
    grandTotal,
    statusNote,
    notes,
    fileName,
  ];
}
