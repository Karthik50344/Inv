import 'dart:io';

import 'package:inventrix/features/backup/data/services/app_storage_locations.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/data/services/zip_backup_packager.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';
import 'package:inventrix/features/backup/domain/usecases/manage_backups.dart';
import 'package:inventrix/features/backup/domain/usecases/prepare_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/restore_backup.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';

import 'backup_fakes.dart' as bk;
import 'fakes.dart';
import 'inventory_fakes.dart';

import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/features/reports/domain/repositories/report_exporter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/app/di/register_blocs.dart';
import 'package:inventrix/app/di/register_usecases.dart';
import 'package:inventrix/app/router/app_router.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';

import 'expense_fakes.dart';
import 'payment_fakes.dart';
import 'purchase_fakes.dart';
import 'return_fakes.dart';
import 'report_fakes.dart';
import 'sales_fakes.dart';

/// A locator wired with in-memory fake repositories and the real use cases
/// and BLoCs, so widget tests exercise the full presentation + domain stack
/// without a database.
class TestWiring {
  TestWiring() {
    products = FakeProductRepository();
    categories = FakeCategoryRepository(products);
    units = FakeUnitRepository(products);
    inventory = FakeInventoryRepository(products, settings.config, clock);
    transactions = FakeTransactionRunner([
      inventory,
      audit,
      purchases,
      salesInvoices,
      sequences,
      payments,
      expenseRepository,
    ]);
    locator
      ..registerSingleton<Clock>(clock)
      ..registerSingleton<IdGenerator>(SequentialIds())
      ..registerSingleton<SettingsRepository>(settings)
      ..registerSingleton<TaxRateRepository>(taxRates)
      ..registerSingleton<ProductRepository>(products)
      ..registerSingleton<CategoryRepository>(categories)
      ..registerSingleton<UnitRepository>(units)
      ..registerSingleton<CustomerRepository>(customers)
      ..registerSingleton<SupplierRepository>(suppliers)
      ..registerSingleton<ImageStorage>(images)
      ..registerSingleton<InventoryRepository>(inventory)
      ..registerSingleton<AuditLogRepository>(audit)
      ..registerSingleton<PurchaseRepository>(purchases)
      ..registerSingleton<SalesRepository>(salesInvoices)
      ..registerSingleton<InvoicePdfRenderer>(pdfRenderer)
      ..registerSingleton<InvoiceFileSharer>(fileSharer)
      ..registerSingleton<DocumentSequenceRepository>(sequences)
      ..registerSingleton<PaymentRepository>(payments)
      ..registerSingleton<InvoicePaymentGuard>(payments)
      ..registerSingleton<PaymentMethodRepository>(paymentMethods)
      ..registerSingleton<ExpenseRepository>(expenseRepository)
      ..registerSingleton<ExpenseCategoryRepository>(expenseCategories)
      ..registerSingleton<AttachmentStorage>(attachmentStorage)
      ..registerSingleton<ReportRepository>(reports)
      ..registerSingleton<ReportExporter>(reportExporter)
      ..registerSingleton<ReturnRepository>(returns)
      ..registerSingleton<InvoiceReturnLookup>(returns)
      ..registerSingleton<InvoiceReturnGuard>(returns)
      ..registerSingleton<TransactionRunner>(transactions);
    registerUseCases(locator);
    registerBlocs(locator);
    _registerBackup();
  }

  /// Backup screen on an empty temp folder with a fake database.
  void _registerBackup() {
    final root = Directory.systemTemp.createTempSync('inventrix_widget_');
    final db = File('${root.path}/inventory_management.sqlite')
      ..writeAsStringSync('data');
    final locations = AppStorageLocations(
      documents: () async => root,
      temporary: () async => root,
      databasePath: () async => db.path,
    );
    final history = bk.InMemoryHistory();
    final inspector = bk.FakeInspector();
    final packager = ZipBackupPackager();
    final ids = bk.SeqIds();
    final backupClock = bk.FakeClock();
    final create = CreateBackup(
      snapshotter: bk.FakeSnapshotter(db),
      inspector: inspector,
      packager: packager,
      locations: locations,
      history: history,
      ids: ids,
      clock: backupClock,
      appVersion: '1.0.0',
    );
    locator.registerFactory<BackupBloc>(
      () => BackupBloc(
        listBackups: ListBackups(history: history, locations: locations),
        createBackup: create,
        exportBackup: ExportBackup(
          history: history,
          locations: locations,
          packager: packager,
          exporter: bk.FakeExporter(),
          clock: backupClock,
        ),
        deleteBackup: DeleteStoredBackup(history: history, locations: locations),
        prepareRestore: PrepareRestore(
          packager: packager,
          inspector: inspector,
          locations: locations,
        ),
        discardStaged: DiscardStagedBackup(locations: locations),
        restoreBackup: RestoreBackup(
          inspector: inspector,
          locations: locations,
          createBackup: create,
          swapper: FileRestoreSwapper(),
          journal: bk.InMemoryJournal(),
          runtime: bk.FakeRuntime(),
          ids: ids,
          clock: backupClock,
        ),
        locations: locations,
      ),
    );
  }

  final GetIt locator = GetIt.asNewInstance();
  final FakeClock clock = FakeClock();
  final FakeSettingsRepository settings = FakeSettingsRepository();
  final FakeTaxRateRepository taxRates = FakeTaxRateRepository();
  final FakeCustomerRepository customers = FakeCustomerRepository();
  final FakeSupplierRepository suppliers = FakeSupplierRepository();
  final FakeImageStorage images = FakeImageStorage();
  late final FakeProductRepository products;
  late final FakeCategoryRepository categories;
  late final FakeUnitRepository units;
  late final FakeInventoryRepository inventory;
  late final FakeTransactionRunner transactions;
  final FakeAuditLogRepository audit = FakeAuditLogRepository();
  final FakePurchaseRepository purchases = FakePurchaseRepository();
  final FakeSalesRepository salesInvoices = FakeSalesRepository();
  final FakeInvoicePdfRenderer pdfRenderer = FakeInvoicePdfRenderer();
  final FakeInvoiceFileSharer fileSharer = FakeInvoiceFileSharer();
  final FakePaymentRepository payments = FakePaymentRepository();
  final FakeReturnRepository returns = FakeReturnRepository();
  final FakeReportRepository reports = FakeReportRepository();
  final FakeReportExporter reportExporter = FakeReportExporter();
  final FakeExpenseRepository expenseRepository = FakeExpenseRepository();
  final FakeExpenseCategoryRepository expenseCategories =
      FakeExpenseCategoryRepository();
  final FakeAttachmentStorage attachmentStorage = FakeAttachmentStorage();
  final FakePaymentMethodRepository paymentMethods =
      FakePaymentMethodRepository();
  final FakeDocumentSequenceRepository sequences =
      FakeDocumentSequenceRepository();

  /// Adds an active unit named `Unit <symbol>`.
  UnitOfMeasure addUnit({
    String id = 'u1',
    String symbol = 'pcs',
    int decimals = 0,
  }) {
    final now = clock.now();
    final unit = UnitOfMeasure(
      id: id,
      name: 'Unit $symbol',
      symbol: symbol,
      decimalPlaces: decimals,
      createdAt: now,
      updatedAt: now,
    );
    units.items[id] = unit;
    return unit;
  }

  /// Adds an active category.
  Category addCategory({String id = 'c1', String name = 'Tools'}) {
    final now = clock.now();
    final category = Category(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    categories.items[id] = category;
    return category;
  }

  /// Router whose screens resolve their BLoCs from this wiring.
  GoRouter router({String initialLocation = '/dashboard'}) =>
      AppRouter.create(initialLocation: initialLocation, locator: locator);
}
