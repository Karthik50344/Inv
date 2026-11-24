import 'dart:io';
import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/invoice_layout.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Reads attachment files and renders invoice PDFs for an export, with the
/// same layout and renderer used when an invoice is shared.
final class AppExportAssetReader implements ExportAssetReader {
  /// Creates the reader.
  const AppExportAssetReader({
    required AttachmentStorage attachments,
    required SalesRepository sales,
    required SettingsRepository settings,
    required InvoicePdfRenderer renderer,
    required String Function(Money) formatMoney,
    required String Function(DateTime) formatDate,
    LogoStorage? logos,
  }) : _attachments = attachments,
       _sales = sales,
       _settings = settings,
       _renderer = renderer,
       _formatMoney = formatMoney,
       _formatDate = formatDate,
       _logos = logos;

  final AttachmentStorage _attachments;
  final SalesRepository _sales;
  final SettingsRepository _settings;
  final InvoicePdfRenderer _renderer;
  final String Function(Money) _formatMoney;
  final String Function(DateTime) _formatDate;
  final LogoStorage? _logos;

  @override
  Future<Result<Uint8List>> attachment(String storedPath) async {
    try {
      final file = File(await _attachments.resolvePath(storedPath));
      if (!await file.exists()) {
        return const Result.failure(ExportFailure('The attachment file is missing.'));
      }
      return Result.success(await file.readAsBytes());
    } on Object catch (error, stack) {
      return Result.failure(
        ExportFailure('The attachment could not be read.', cause: error, stackTrace: stack),
      );
    }
  }

  @override
  Future<Result<Uint8List>> invoicePdf(String invoiceId) async {
    final loaded = await _sales.getById(invoiceId);
    final invoice = loaded.valueOrNull;
    if (invoice == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final profile = await _settings.getBusinessProfile();
    final business = profile.valueOrNull;
    if (business == null) {
      return Result.failure(profile.failureOrNull!);
    }
    final layout = InvoiceLayout.from(
      invoice,
      business,
      money: _formatMoney,
      date: _formatDate,
    );
    final logoPath = business.logoPath;
    final logo = logoPath == null ? null : await _logos?.read(logoPath);
    return _renderer.render(
      layout,
      logo: logo == null ? null : Uint8List.fromList(logo),
    );
  }
}
