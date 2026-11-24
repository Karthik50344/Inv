import 'package:flutter/material.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Plain-language texts of the export screens.
abstract final class ExportLabels {
  /// `1.4 MB`.
  static String size(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// What a dataset contains, in words an owner understands.
  static String datasetHelp(ExportDataset dataset) => switch (dataset) {
    ExportDataset.businessProfile => 'Your company name, address and tax number.',
    ExportDataset.products => 'Every product as it is today.',
    ExportDataset.productClassifications => 'HSN / SAC / HS codes of your products.',
    ExportDataset.customers => 'Your customers as they are today.',
    ExportDataset.suppliers => 'Your suppliers as they are today.',
    ExportDataset.salesInvoices => 'Invoices and their lines in the period.',
    ExportDataset.salesReturns => 'Returns from customers in the period.',
    ExportDataset.purchaseInvoices => 'Purchase bills and their lines in the period.',
    ExportDataset.purchaseReturns => 'Returns to suppliers in the period.',
    ExportDataset.payments => 'Payments, what they were applied to, and reversals.',
    ExportDataset.expenses => 'Expenses in the period.',
    ExportDataset.inventoryBalances => 'Stock on hand and its value today.',
    ExportDataset.stockMovements => 'Every stock in and out in the period.',
    ExportDataset.taxConfigurations => 'Your tax categories, rules and rates as they are today.',
    ExportDataset.taxSummaries => 'Tax totals by tax type, from posted documents.',
    ExportDataset.hsnSummaries => 'Totals by HSN / SAC code, from posted documents.',
    ExportDataset.auditTrail => 'Who did what and when, with an integrity report.',
    ExportDataset.attachments => 'Receipt photos and files attached to expenses.',
    ExportDataset.invoicePdfs => 'A PDF of each sales invoice in the period.',
  };

  /// What a format gives the auditor.
  static String formatHelp(ExportFormat format) => switch (format) {
    ExportFormat.zip => 'Everything in one package with a list of checksums. Best for an auditor.',
    ExportFormat.csv => 'Plain files that open in any spreadsheet program.',
    ExportFormat.xlsx => 'One Excel workbook with a sheet for each list.',
    ExportFormat.pdf => 'A printable summary. It does not list every transaction.',
  };

  /// A badge for the integrity state of an export.
  static Widget integrityBadge(ExportRecord record) {
    if (!record.hasFile) {
      return const AppBadge(label: 'File removed', tone: AppTone.neutral, icon: Icons.delete_outline);
    }
    switch (record.integrityStatus) {
      case 'verified':
        return const AppBadge(label: 'Verified', tone: AppTone.success, icon: Icons.verified_outlined);
      case 'failed':
        return const AppBadge(label: 'Check failed', tone: AppTone.danger, icon: Icons.gpp_bad_outlined);
      default:
        return const AppBadge(label: 'Not checked', tone: AppTone.warning, icon: Icons.help_outline);
    }
  }

  /// The audit chain state at export time, in words.
  static String chain(String status) => switch (status) {
    'intact' => 'No change detected in the audit log',
    'broken' => 'The audit log showed a problem',
    'empty' => 'No audit events existed yet',
    _ => 'The audit log could not be checked',
  };
}
