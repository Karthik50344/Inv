import 'package:get_it/get_it.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/categories/data/repositories/drift_category_repository.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/expenses/data/repositories/drift_expense_category_repository.dart';
import 'package:inventrix/features/expenses/data/repositories/drift_expense_repository.dart';
import 'package:inventrix/features/expenses/data/repositories/file_attachment_storage.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/payments/data/repositories/drift_payment_method_repository.dart';
import 'package:inventrix/features/payments/data/repositories/drift_payment_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/products/data/repositories/drift_product_repository.dart';
import 'package:inventrix/features/products/data/repositories/drift_unit_repository.dart';
import 'package:inventrix/features/products/data/repositories/file_image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/purchases/data/repositories/drift_purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/reports/data/repositories/drift_report_repository.dart';
import 'package:inventrix/features/reports/data/repositories/share_plus_report_exporter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_exporter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/features/returns/data/repositories/drift_return_repository.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/features/sales/data/repositories/drift_sales_repository.dart';
import 'package:inventrix/features/sales/data/services/pdf_invoice_renderer.dart';
import 'package:inventrix/features/sales/data/services/share_plus_invoice_sharer.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:inventrix/features/settings/data/repositories/drift_business_profile_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_currency_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_numbering_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_preferences_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_settings_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_tax_rate_repository.dart';
import 'package:inventrix/features/settings/data/repositories/file_logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/business_profile_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/currency_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/numbering_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/features/suppliers/data/repositories/drift_supplier_repository.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/data/drift_document_sequence_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';

/// Registers repository implementations backed by Drift and the file system.
void registerRepositories(GetIt locator) {
  locator
    ..registerLazySingleton<SettingsRepository>(
      () => DriftSettingsRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<PreferencesRepository>(
      () => DriftPreferencesRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<BusinessProfileRepository>(
      () => DriftBusinessProfileRepository(
        locator<AppDatabase>(),
        locator<IdGenerator>(),
        locator<Clock>(),
      ),
    )
    ..registerLazySingleton<CurrencyRepository>(
      () => DriftCurrencyRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<NumberingRepository>(
      () => DriftNumberingRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<LogoStorage>(
      () =>
          FileLogoStorage(ids: locator<IdGenerator>(), clock: locator<Clock>()),
    )
    ..registerLazySingleton<TaxRateRepository>(
      () => DriftTaxRateRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => DriftCategoryRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<UnitRepository>(
      () => DriftUnitRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<ProductRepository>(
      () => DriftProductRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<CustomerRepository>(
      () => DriftCustomerRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<SupplierRepository>(
      () => DriftSupplierRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<AuditLogRepository>(
      () => DriftAuditLogRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<InventoryRepository>(
      () => DriftInventoryRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
        locator<ProductRepository>(),
      ),
    )
    ..registerLazySingleton<DocumentSequenceRepository>(
      () => DriftDocumentSequenceRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<PurchaseRepository>(
      () => DriftPurchaseRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<SalesRepository>(
      () => DriftSalesRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<DriftPaymentRepository>(
      () => DriftPaymentRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<PaymentRepository>(
      () => locator<DriftPaymentRepository>(),
    )
    ..registerLazySingleton<DriftReturnRepository>(
      () => DriftReturnRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<ReturnRepository>(
      () => locator<DriftReturnRepository>(),
    )
    ..registerLazySingleton<InvoiceReturnLookup>(
      () => locator<DriftReturnRepository>(),
    )
    ..registerLazySingleton<InvoiceReturnGuard>(
      () => locator<DriftReturnRepository>(),
    )
    ..registerLazySingleton<InvoicePaymentGuard>(
      () => locator<DriftPaymentRepository>(),
    )
    ..registerLazySingleton<PaymentMethodRepository>(
      () => DriftPaymentMethodRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<ExpenseRepository>(
      () => DriftExpenseRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<ExpenseCategoryRepository>(
      () => DriftExpenseCategoryRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<AttachmentStorage>(
      () => FileAttachmentStorage(
        ids: locator<IdGenerator>(),
        clock: locator<Clock>(),
      ),
    )
    ..registerLazySingleton<ReportRepository>(
      () => DriftReportRepository(
        locator<AppDatabase>(),
        locator<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton<ReportExporter>(SharePlusReportExporter.new)
    ..registerLazySingleton<InvoicePdfRenderer>(PdfInvoiceRenderer.new)
    ..registerLazySingleton<InvoiceFileSharer>(SharePlusInvoiceFileSharer.new)
    ..registerLazySingleton<ImageStorage>(
      () => FileImageStorage(
        ids: locator<IdGenerator>(),
        clock: locator<Clock>(),
      ),
    );
}
