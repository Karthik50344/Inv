import 'package:get_it/get_it.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';
import 'package:inventrix/features/auditor_exports/data/repositories/drift_export_history_repository.dart';
import 'package:inventrix/features/auditor_exports/data/services/app_export_asset_reader.dart';
import 'package:inventrix/features/auditor_exports/data/services/drift_export_data_source.dart';
import 'package:inventrix/features/auditor_exports/data/services/file_export_store.dart';
import 'package:inventrix/features/auditor_exports/data/services/pdf_export_writer.dart';
import 'package:inventrix/features/auditor_exports/data/services/sha256_byte_hasher.dart';
import 'package:inventrix/features/auditor_exports/data/services/xml_xlsx_writer.dart';
import 'package:inventrix/features/auditor_exports/data/services/zip_export_codec.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/auditor_exports/domain/services/byte_hasher.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/export_history_use_cases.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/generate_auditor_export.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Registers the auditor export feature. Exports are kept in their own
/// `exports` folder, separate from the backup folder.
void registerExports(GetIt locator) {
  locator
    ..registerLazySingleton<ByteHasher>(() => const Sha256ByteHasher())
    ..registerLazySingleton<ExportDataSource>(
      () => DriftExportDataSource(locator<AppDatabase>()),
    )
    ..registerLazySingleton<ExportAssetReader>(
      () => AppExportAssetReader(
        attachments: locator<AttachmentStorage>(),
        sales: locator<SalesRepository>(),
        settings: locator<SettingsRepository>(),
        renderer: locator<InvoicePdfRenderer>(),
        // Same as the shared invoice PDF: built-in PDF fonts lack currency
        // symbols, so the ISO code is printed.
        formatMoney: (money) =>
            '${money.currencyCode} '
            '${const MoneyFormatter().format(money, withSymbol: false)}',
        formatDate: DateFormatter.date,
        logos: locator<LogoStorage>(),
      ),
    )
    ..registerLazySingleton<XlsxWriter>(() => const XmlXlsxWriter())
    ..registerLazySingleton<ExportPdfWriter>(() => const PdfExportWriter())
    ..registerLazySingleton<ExportZipCodec>(() => const ArchiveExportZipCodec())
    ..registerLazySingleton<ExportFileStore>(
      () => FileExportStore(() async {
        final base = await getApplicationDocumentsDirectory();
        return p.join(base.path, 'exports');
      }),
    )
    ..registerLazySingleton<ExportHistoryRepository>(
      () => DriftExportHistoryRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton(
      () => GenerateAuditorExport(
        source: locator<ExportDataSource>(),
        assets: locator<ExportAssetReader>(),
        hasher: locator<ByteHasher>(),
        xlsx: locator<XlsxWriter>(),
        pdf: locator<ExportPdfWriter>(),
        zip: locator<ExportZipCodec>(),
        store: locator<ExportFileStore>(),
        history: locator<ExportHistoryRepository>(),
        verifyChain: locator<VerifyAuditChain>(),
        checkpoint: locator<CreateAuditCheckpoint>(),
        recorder: locator<AuditRecorder>(),
        clock: locator<Clock>(),
        ids: locator<IdGenerator>(),
        appVersion: AppConstants.appVersion,
      ),
    )
    ..registerLazySingleton(
      () => ListExportHistory(locator<ExportHistoryRepository>()),
    )
    ..registerLazySingleton(
      () => VerifyExportFile(
        history: locator<ExportHistoryRepository>(),
        store: locator<ExportFileStore>(),
        zip: locator<ExportZipCodec>(),
        hasher: locator<ByteHasher>(),
        clock: locator<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ShareExportFile(
        history: locator<ExportHistoryRepository>(),
        store: locator<ExportFileStore>(),
        exporter: locator<BackupExporter>(),
        recorder: locator<AuditRecorder>(),
      ),
    )
    ..registerLazySingleton(
      () => DeleteExportFile(
        history: locator<ExportHistoryRepository>(),
        store: locator<ExportFileStore>(),
        recorder: locator<AuditRecorder>(),
        clock: locator<Clock>(),
      ),
    );
}
