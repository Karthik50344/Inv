import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/invoice_layout.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Builds the PDF of a posted (or voided) sales invoice and shares it.
///
/// The PDF is generated from the stored invoice, never from screen state,
/// so it always matches the saved document and its own snapshots.
final class ShareInvoicePdf {
  /// Creates the use case. [formatMoney] and [formatDate] provide display
  /// formatting (kept out of the domain).
  const ShareInvoicePdf({
    required SalesRepository sales,
    required SettingsRepository settings,
    required InvoicePdfRenderer renderer,
    required InvoiceFileSharer sharer,
    required String Function(Money) formatMoney,
    required String Function(DateTime) formatDate,
    LogoStorage? logos,
  }) : _logos = logos,
       _sales = sales,
       _settings = settings,
       _renderer = renderer,
       _sharer = sharer,
       _formatMoney = formatMoney,
       _formatDate = formatDate;

  final LogoStorage? _logos;
  final SalesRepository _sales;
  final SettingsRepository _settings;
  final InvoicePdfRenderer _renderer;
  final InvoiceFileSharer _sharer;
  final String Function(Money) _formatMoney;
  final String Function(DateTime) _formatDate;

  /// Shares invoice [id] as a PDF.
  Future<Result<void>> call(String id) async {
    final loaded = await _sales.getById(id);
    final invoice = loaded.valueOrNull;
    if (invoice == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (invoice.status != DocumentStatus.posted &&
        invoice.status != DocumentStatus.voided) {
      return const Result.failure(
        ValidationFailure('Post the sale before sharing its invoice.'),
      );
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
    final logoBytes = logoPath == null ? null : await _logos?.read(logoPath);
    final pdf = await _renderer.render(
      layout,
      logo: logoBytes == null ? null : Uint8List.fromList(logoBytes),
    );
    final bytes = pdf.valueOrNull;
    if (bytes == null) {
      return Result.failure(pdf.failureOrNull!);
    }
    return _sharer.share(
      bytes: bytes,
      fileName: layout.fileName,
      subject: 'Invoice ${invoice.displayNumber}',
    );
  }
}
