import 'package:get_it/get_it.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/categories/domain/usecases/archive_category.dart';
import 'package:inventrix/features/categories/domain/usecases/create_category.dart';
import 'package:inventrix/features/categories/domain/usecases/restore_category.dart';
import 'package:inventrix/features/categories/domain/usecases/update_category.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/customers/domain/usecases/archive_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/restore_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/update_customer.dart';
import 'package:inventrix/features/dashboard/domain/usecases/get_dashboard.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/usecases/cancel_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_categories.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/save_expense_draft.dart';
import 'package:inventrix/features/expenses/domain/usecases/void_expense.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_operation_support.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/features/inventory/domain/usecases/record_opening_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/repair_inventory_balances.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/allocation_checker.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/payments/domain/usecases/allocate_payment_credit.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/features/payments/domain/usecases/manage_payment_methods.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/payments/domain/usecases/record_refund.dart';
import 'package:inventrix/features/payments/domain/usecases/reverse_payment.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/services/product_validator.dart';
import 'package:inventrix/features/products/domain/usecases/add_common_units.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/archive_unit.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_unit.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_unit.dart';
import 'package:inventrix/features/products/domain/usecases/update_product.dart';
import 'package:inventrix/features/products/domain/usecases/update_unit.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_line_builder.dart';
import 'package:inventrix/features/purchases/domain/usecases/get_supplier_payable.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/save_purchase_draft.dart';
import 'package:inventrix/features/purchases/domain/usecases/transition_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/void_purchase.dart';
import 'package:inventrix/features/reports/domain/repositories/report_exporter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/features/reports/domain/services/report_filter_options.dart';
import 'package:inventrix/features/reports/domain/usecases/build_report.dart';
import 'package:inventrix/features/reports/domain/usecases/export_report.dart';
import 'package:inventrix/features/reports/domain/usecases/get_profit_figures.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/features/returns/domain/services/returnable_invoice_loader.dart';
import 'package:inventrix/features/returns/domain/usecases/post_return.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:inventrix/features/sales/domain/services/sales_line_builder.dart';
import 'package:inventrix/features/sales/domain/services/sales_stock_check.dart';
import 'package:inventrix/features/sales/domain/usecases/get_customer_receivable.dart';
import 'package:inventrix/features/sales/domain/usecases/post_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/save_sales_draft.dart';
import 'package:inventrix/features/sales/domain/usecases/share_invoice_pdf.dart';
import 'package:inventrix/features/sales/domain/usecases/transition_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/void_sale.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/features/settings/domain/repositories/business_profile_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/currency_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/numbering_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/features/settings/domain/usecases/change_currency.dart';
import 'package:inventrix/features/settings/domain/usecases/create_tax_rate.dart';
import 'package:inventrix/features/settings/domain/usecases/manage_tax_rates.dart';
import 'package:inventrix/features/settings/domain/usecases/save_business_profile.dart';
import 'package:inventrix/features/settings/domain/usecases/save_numbering.dart';
import 'package:inventrix/features/settings/domain/usecases/update_preferences.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/features/suppliers/domain/usecases/archive_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/create_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/restore_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/update_supplier.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';

/// Registers use cases and domain services (stateless, so singletons).
void registerUseCases(GetIt g) {
  g
    ..registerLazySingleton(
      () => CreateTaxRate(
        repository: g<TaxRateRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdateTaxRate(
        repository: g<TaxRateRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => SetTaxRateArchived(
        repository: g<TaxRateRepository>(),
        preferences: g<PreferencesRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => SetDefaultTaxRate(
        taxRates: g<TaxRateRepository>(),
        preferences: g<PreferencesRepository>(),
        transactions: g<TransactionRunner>(),
      ),
    )
    ..registerLazySingleton(
      () => SaveBusinessProfile(
        repository: g<BusinessProfileRepository>(),
        logos: g<LogoStorage>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ChangeCurrency(
        currencies: g<CurrencyRepository>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdatePreferences(
        repository: g<PreferencesRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => SaveNumbering(
        repository: g<NumberingRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => SetNextDocumentNumber(
        repository: g<NumberingRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    // Categories
    ..registerLazySingleton(
      () => CreateCategory(
        repository: g<CategoryRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdateCategory(
        repository: g<CategoryRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ArchiveCategory(
        repository: g<CategoryRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => RestoreCategory(
        repository: g<CategoryRepository>(),
        clock: g<Clock>(),
      ),
    )
    // Units
    ..registerLazySingleton(
      () => CreateUnit(
        repository: g<UnitRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdateUnit(repository: g<UnitRepository>(), clock: g<Clock>()),
    )
    ..registerLazySingleton(
      () => ArchiveUnit(repository: g<UnitRepository>(), clock: g<Clock>()),
    )
    ..registerLazySingleton(
      () => RestoreUnit(repository: g<UnitRepository>(), clock: g<Clock>()),
    )
    ..registerLazySingleton(
      () => AddCommonUnits(
        repository: g<UnitRepository>(),
        createUnit: g<CreateUnit>(),
      ),
    )
    // Products
    ..registerLazySingleton(
      () => ProductValidator(
        products: g<ProductRepository>(),
        categories: g<CategoryRepository>(),
        units: g<UnitRepository>(),
        taxRates: g<TaxRateRepository>(),
        settings: g<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => CreateProduct(
        validator: g<ProductValidator>(),
        products: g<ProductRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdateProduct(
        validator: g<ProductValidator>(),
        products: g<ProductRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ArchiveProduct(products: g<ProductRepository>(), clock: g<Clock>()),
    )
    ..registerLazySingleton(
      () => RestoreProduct(products: g<ProductRepository>(), clock: g<Clock>()),
    )
    // Inventory
    ..registerLazySingleton(
      () => StockOperationSupport(
        products: g<ProductRepository>(),
        units: g<UnitRepository>(),
        settings: g<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => RecordOpeningStock(
        support: g<StockOperationSupport>(),
        inventory: g<InventoryRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => AdjustStock(
        support: g<StockOperationSupport>(),
        inventory: g<InventoryRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ReconcileInventory(inventory: g<InventoryRepository>()),
    )
    ..registerLazySingleton(
      () => RepairInventoryBalances(
        reconcile: g<ReconcileInventory>(),
        inventory: g<InventoryRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    // Customers
    ..registerLazySingleton(
      () => CreateCustomer(
        repository: g<CustomerRepository>(),
        settings: g<SettingsRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdateCustomer(
        repository: g<CustomerRepository>(),
        settings: g<SettingsRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ArchiveCustomer(
        repository: g<CustomerRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => RestoreCustomer(
        repository: g<CustomerRepository>(),
        clock: g<Clock>(),
      ),
    )
    // Suppliers
    ..registerLazySingleton(
      () => CreateSupplier(
        repository: g<SupplierRepository>(),
        settings: g<SettingsRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdateSupplier(
        repository: g<SupplierRepository>(),
        settings: g<SettingsRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ArchiveSupplier(
        repository: g<SupplierRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => RestoreSupplier(
        repository: g<SupplierRepository>(),
        clock: g<Clock>(),
      ),
    )
    // Purchases
    ..registerLazySingleton(
      () => PurchaseLineBuilder(
        products: g<ProductRepository>(),
        units: g<UnitRepository>(),
        taxRates: g<TaxRateRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => SavePurchaseDraft(
        purchases: g<PurchaseRepository>(),
        suppliers: g<SupplierRepository>(),
        lineBuilder: g<PurchaseLineBuilder>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => TransitionPurchase(
        purchases: g<PurchaseRepository>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => PostPurchase(
        purchases: g<PurchaseRepository>(),
        suppliers: g<SupplierRepository>(),
        products: g<ProductRepository>(),
        inventory: g<InventoryRepository>(),
        sequences: g<DocumentSequenceRepository>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => VoidPurchase(
        purchases: g<PurchaseRepository>(),
        inventory: g<InventoryRepository>(),
        audit: g<AuditLogRepository>(),
        payments: g<InvoicePaymentGuard>(),
        returns: g<InvoiceReturnGuard>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => GetSupplierPayable(
        purchases: g<PurchaseRepository>(),
        suppliers: g<SupplierRepository>(),
      ),
    )
    // Sales
    ..registerLazySingleton(
      () => SalesLineBuilder(
        products: g<ProductRepository>(),
        units: g<UnitRepository>(),
        taxRates: g<TaxRateRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => SalesStockCheck(inventory: g<InventoryRepository>()),
    )
    ..registerLazySingleton(
      () => SaveSalesDraft(
        sales: g<SalesRepository>(),
        customers: g<CustomerRepository>(),
        lineBuilder: g<SalesLineBuilder>(),
        stockCheck: g<SalesStockCheck>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => TransitionSale(
        sales: g<SalesRepository>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => PostSale(
        sales: g<SalesRepository>(),
        customers: g<CustomerRepository>(),
        products: g<ProductRepository>(),
        inventory: g<InventoryRepository>(),
        sequences: g<DocumentSequenceRepository>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => VoidSale(
        sales: g<SalesRepository>(),
        inventory: g<InventoryRepository>(),
        audit: g<AuditLogRepository>(),
        payments: g<InvoicePaymentGuard>(),
        returns: g<InvoiceReturnGuard>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => GetCustomerReceivable(
        sales: g<SalesRepository>(),
        customers: g<CustomerRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => ShareInvoicePdf(
        sales: g<SalesRepository>(),
        settings: g<SettingsRepository>(),
        renderer: g<InvoicePdfRenderer>(),
        sharer: g<InvoiceFileSharer>(),
        // The built-in PDF fonts lack currency symbols such as the rupee
        // sign, so invoices print the ISO currency code instead.
        formatMoney: (money) =>
            '${money.currencyCode} '
            '${const MoneyFormatter().format(money, withSymbol: false)}',
        formatDate: formatDocumentDate,
        logos: g<LogoStorage>(),
      ),
    )
    ..registerLazySingleton(
      () => ReturnableInvoiceLoader(
        sales: g<SalesRepository>(),
        purchases: g<PurchaseRepository>(),
        returns: g<ReturnRepository>(),
        ledger: g<InvoiceLedger>(),
        inventory: g<InventoryRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => PostReturn(
        loader: g<ReturnableInvoiceLoader>(),
        returns: g<ReturnRepository>(),
        inventory: g<InventoryRepository>(),
        methods: g<PaymentMethodRepository>(),
        sequences: g<DocumentSequenceRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => PartyDirectory(
        customers: g<CustomerRepository>(),
        suppliers: g<SupplierRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => InvoiceLedger(
        sales: g<SalesRepository>(),
        purchases: g<PurchaseRepository>(),
        payments: g<PaymentRepository>(),
        returns: g<InvoiceReturnLookup>(),
      ),
    )
    ..registerLazySingleton(() => AllocationChecker(g<InvoiceLedger>()))
    ..registerLazySingleton(
      () => RecordPayment(
        payments: g<PaymentRepository>(),
        methods: g<PaymentMethodRepository>(),
        parties: g<PartyDirectory>(),
        allocations: g<AllocationChecker>(),
        settings: g<SettingsRepository>(),
        sequences: g<DocumentSequenceRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => AllocatePaymentCredit(
        payments: g<PaymentRepository>(),
        allocations: g<AllocationChecker>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ReversePayment(
        payments: g<PaymentRepository>(),
        ledger: g<InvoiceLedger>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => RecordRefund(
        payments: g<PaymentRepository>(),
        methods: g<PaymentMethodRepository>(),
        sequences: g<DocumentSequenceRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => GetPartyBalance(
        parties: g<PartyDirectory>(),
        sales: g<SalesRepository>(),
        purchases: g<PurchaseRepository>(),
        payments: g<PaymentRepository>(),
        returns: g<InvoiceReturnLookup>(),
        settings: g<SettingsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => GetOpenInvoices(
        ledger: g<InvoiceLedger>(),
        payments: g<PaymentRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => CreatePaymentMethod(
        methods: g<PaymentMethodRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => SetPaymentMethodArchived(
        methods: g<PaymentMethodRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => CreateExpenseCategory(
        categories: g<ExpenseCategoryRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => UpdateExpenseCategory(
        categories: g<ExpenseCategoryRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => SetExpenseCategoryArchived(
        categories: g<ExpenseCategoryRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => SaveExpenseDraft(
        expenses: g<ExpenseRepository>(),
        categories: g<ExpenseCategoryRepository>(),
        methods: g<PaymentMethodRepository>(),
        taxRates: g<TaxRateRepository>(),
        settings: g<SettingsRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => PostExpense(
        expenses: g<ExpenseRepository>(),
        categories: g<ExpenseCategoryRepository>(),
        methods: g<PaymentMethodRepository>(),
        sequences: g<DocumentSequenceRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => CancelExpense(
        expenses: g<ExpenseRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => VoidExpense(
        expenses: g<ExpenseRepository>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => AddExpenseAttachment(
        expenses: g<ExpenseRepository>(),
        storage: g<AttachmentStorage>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => RemoveExpenseAttachment(
        expenses: g<ExpenseRepository>(),
        storage: g<AttachmentStorage>(),
        audit: g<AuditLogRepository>(),
        transactions: g<TransactionRunner>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ReportFilterOptions(
        products: g<ProductRepository>(),
        parties: g<PartyDirectory>(),
      ),
    )
    ..registerLazySingleton(
      () => GetProfitFigures(
        reports: g<ReportRepository>(),
        expenses: g<ExpenseRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => BuildReport(
        reports: g<ReportRepository>(),
        expenses: g<ExpenseRepository>(),
        profit: g<GetProfitFigures>(),
        inventory: g<InventoryRepository>(),
        units: g<UnitRepository>(),
        balances: g<GetPartyBalance>(),
        options: g<ReportFilterOptions>(),
        settings: g<SettingsRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => GetDashboard(
        reports: g<ReportRepository>(),
        expenses: g<ExpenseRepository>(),
        inventory: g<InventoryRepository>(),
        balances: g<GetPartyBalance>(),
        profit: g<GetProfitFigures>(),
        settings: g<SettingsRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton(
      () => ExportReportCsv(exporter: g<ReportExporter>()),
    );
}
