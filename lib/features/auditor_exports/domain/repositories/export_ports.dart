import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_report.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';

/// An attachment file to include.
final class ExportAttachment extends Equatable {
  /// Creates a reference.
  const ExportAttachment({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.fileName,
    required this.storedPath,
  });

  /// Attachment id.
  final String id;

  /// What it belongs to (`expense`).
  final String ownerType;

  /// The owning record.
  final String ownerId;

  /// Original file name.
  final String fileName;

  /// Path in the app's private storage.
  final String storedPath;

  @override
  List<Object?> get props => [id, ownerType, ownerId, fileName, storedPath];
}

/// A posted sales invoice whose PDF can be included.
final class ExportInvoiceRef extends Equatable {
  /// Creates a reference.
  const ExportInvoiceRef({required this.id, required this.number});

  /// Invoice id.
  final String id;

  /// Invoice number.
  final String number;

  @override
  List<Object?> get props => [id, number];
}

/// Reads data for an export. Every read made inside [inSnapshot] sees the
/// same consistent state and changes nothing.
abstract interface class ExportDataSource {
  /// Runs [action] in one read-only transaction.
  Future<Result<T>> inSnapshot<T>(
    Future<T> Function(ExportSnapshot snapshot) action,
  );
}

/// One consistent view of the data.
abstract interface class ExportSnapshot {
  /// The tables of [dataset] filtered by [period].
  Future<List<ExportTable>> tables(ExportDataset dataset, ExportPeriod period);

  /// The database schema version.
  Future<int> schemaVersion();

  /// Attachment files in the period.
  Future<List<ExportAttachment>> attachments(ExportPeriod period);

  /// Posted or voided sales invoices in the period.
  Future<List<ExportInvoiceRef>> salesInvoices(ExportPeriod period);
}

/// Reads file contents that live outside the database.
abstract interface class ExportAssetReader {
  /// The bytes of the attachment stored at [storedPath].
  Future<Result<Uint8List>> attachment(String storedPath);

  /// The PDF of sales invoice [invoiceId].
  Future<Result<Uint8List>> invoicePdf(String invoiceId);
}

/// Writes XLSX workbooks.
abstract interface class XlsxWriter {
  /// A workbook with one sheet per table.
  Uint8List write(List<ExportTable> sheets);
}

/// Renders the PDFs of an export.
abstract interface class ExportPdfWriter {
  /// The PDF report format.
  Future<Uint8List> report(ExportReport report);

  /// The audit integrity report.
  Future<Uint8List> integrity(IntegrityReport report);

  /// The business profile as a PDF.
  Future<Uint8List> businessProfile(ExportTable profile);
}

/// ZIP reading and writing.
abstract interface class ExportZipCodec {
  /// A ZIP with the given files.
  Uint8List encode(Map<String, Uint8List> files);

  /// The files of a ZIP. Fails on unsafe paths.
  Result<Map<String, Uint8List>> decode(Uint8List bytes);
}

/// Where finished exports are kept on the device.
abstract interface class ExportFileStore {
  /// Writes [bytes] as [fileName] and returns the absolute path.
  Future<String> write(String fileName, Uint8List bytes);

  /// The bytes of [fileName], or `null` when missing.
  Future<Uint8List?> read(String fileName);

  /// Absolute path of [fileName].
  Future<String> resolve(String fileName);

  /// Removes [fileName] if it exists.
  Future<void> delete(String fileName);
}

/// Stores the export history.
abstract interface class ExportHistoryRepository {
  /// Adds a record.
  Future<Result<void>> add(ExportRecord record);

  /// Records, newest first.
  Future<Result<List<ExportRecord>>> list({int limit = 100});

  /// One record, or `null`.
  Future<Result<ExportRecord?>> getById(String id);

  /// Stores the result of an integrity check.
  Future<Result<void>> updateIntegrity(
    String id, {
    required String status,
    required DateTime at,
  });

  /// Marks the file as removed from the device.
  Future<Result<void>> markFileDeleted(String id, DateTime at);
}
