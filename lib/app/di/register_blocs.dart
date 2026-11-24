import 'package:get_it/get_it.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_operator_repository.dart';
import 'package:inventrix/features/audit/domain/usecases/save_audit_operator_name.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_config_repository.dart';
import 'package:inventrix/features/taxation/domain/usecases/tax_config_editor.dart';
import 'package:inventrix/features/taxation/presentation/bloc/tax_settings_cubit.dart';
import 'package:inventrix/features/product_classification/domain/repositories/product_classification_repository.dart';
import 'package:inventrix/features/product_classification/domain/usecases/classification_use_cases.dart';
import 'package:inventrix/features/products/domain/usecases/set_product_tax_treatment.dart';
import 'package:inventrix/features/products/presentation/bloc/product_tax_cubit.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_query_repository.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_center_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_event_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_integrity_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_log_cubit.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/export_history_use_cases.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_history_cubit.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/categories/domain/usecases/archive_category.dart';
import 'package:inventrix/features/categories/domain/usecases/create_category.dart';
import 'package:inventrix/features/categories/domain/usecases/restore_category.dart';
import 'package:inventrix/features/categories/domain/usecases/update_category.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_cubit.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/customers/domain/usecases/archive_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/restore_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/update_customer.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_bloc.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_detail_cubit.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_form_cubit.dart';
import 'package:inventrix/features/dashboard/domain/usecases/get_dashboard.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/usecases/cancel_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_categories.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/save_expense_draft.dart';
import 'package:inventrix/features/expenses/domain/usecases/void_expense.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_categories_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_detail_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_form_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_report_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/features/inventory/domain/usecases/record_opening_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/repair_inventory_balances.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:inventrix/features/inventory/presentation/bloc/reconciliation_cubit.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_detail_cubit.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_operation_cubit.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/payments/domain/usecases/allocate_payment_credit.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/features/payments/domain/usecases/manage_payment_methods.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/payments/domain/usecases/record_refund.dart';
import 'package:inventrix/features/payments/domain/usecases/reverse_payment.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_detail_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_form_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_methods_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/usecases/add_common_units.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/archive_unit.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_unit.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_unit.dart';
import 'package:inventrix/features/products/domain/usecases/update_product.dart';
import 'package:inventrix/features/products/domain/usecases/update_unit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_bloc.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/unit_cubit.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_line_builder.dart';
import 'package:inventrix/features/purchases/domain/usecases/get_supplier_payable.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/save_purchase_draft.dart';
import 'package:inventrix/features/purchases/domain/usecases/transition_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/void_purchase.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_bloc.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_detail_cubit.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_form_cubit.dart';
import 'package:inventrix/features/reports/domain/services/report_filter_options.dart';
import 'package:inventrix/features/reports/domain/usecases/build_report.dart';
import 'package:inventrix/features/reports/domain/usecases/export_report.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_bloc.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/features/returns/domain/services/returnable_invoice_loader.dart';
import 'package:inventrix/features/returns/domain/usecases/post_return.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_detail_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_form_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/returns_bloc.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/sales_line_builder.dart';
import 'package:inventrix/features/sales/domain/services/sales_stock_check.dart';
import 'package:inventrix/features/sales/domain/usecases/get_customer_receivable.dart';
import 'package:inventrix/features/sales/domain/usecases/post_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/save_sales_draft.dart';
import 'package:inventrix/features/sales/domain/usecases/share_invoice_pdf.dart';
import 'package:inventrix/features/sales/domain/usecases/transition_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/void_sale.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_form_cubit.dart';
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
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/tax_rates_cubit.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/features/suppliers/domain/usecases/archive_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/create_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/restore_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/update_supplier.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_bloc.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_detail_cubit.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_form_cubit.dart';

/// Registers BLoCs and Cubits as factories: every screen gets a fresh one.
void registerBlocs(GetIt g) {
  g
    ..registerFactory(
      () => CategoryCubit(
        repository: g<CategoryRepository>(),
        createCategory: g<CreateCategory>(),
        updateCategory: g<UpdateCategory>(),
        archiveCategory: g<ArchiveCategory>(),
        restoreCategory: g<RestoreCategory>(),
      ),
    )
    ..registerFactory(
      () => UnitCubit(
        repository: g<UnitRepository>(),
        createUnit: g<CreateUnit>(),
        updateUnit: g<UpdateUnit>(),
        archiveUnit: g<ArchiveUnit>(),
        restoreUnit: g<RestoreUnit>(),
        addCommonUnits: g<AddCommonUnits>(),
      ),
    )
    ..registerFactory(
      () => ProductBloc(
        products: g<ProductRepository>(),
        categories: g<CategoryRepository>(),
        units: g<UnitRepository>(),
        archiveProduct: g<ArchiveProduct>(),
        restoreProduct: g<RestoreProduct>(),
        imageStorage: g<ImageStorage>(),
      ),
    )
    ..registerFactory(
      () => ProductFormCubit(
        products: g<ProductRepository>(),
        categories: g<CategoryRepository>(),
        units: g<UnitRepository>(),
        taxRates: g<TaxRateRepository>(),
        settings: g<SettingsRepository>(),
        createProduct: g<CreateProduct>(),
        updateProduct: g<UpdateProduct>(),
        createTaxRate: g<CreateTaxRate>(),
        imageStorage: g<ImageStorage>(),
        preferences: g<PreferencesRepository>(),
      ),
    )
    ..registerFactory(
      () => ProductDetailCubit(
        products: g<ProductRepository>(),
        categories: g<CategoryRepository>(),
        units: g<UnitRepository>(),
        taxRates: g<TaxRateRepository>(),
        archiveProduct: g<ArchiveProduct>(),
        restoreProduct: g<RestoreProduct>(),
        imageStorage: g<ImageStorage>(),
      ),
    )
    ..registerFactoryParam<InventoryBloc, StockFilter?, void>(
      (filter, _) => InventoryBloc(
        inventory: g<InventoryRepository>(),
        units: g<UnitRepository>(),
        initialFilter: filter ?? const StockFilter(),
      ),
    )
    ..registerFactory(
      () => StockDetailCubit(
        inventory: g<InventoryRepository>(),
        units: g<UnitRepository>(),
      ),
    )
    ..registerFactory(
      () => StockOperationCubit(
        inventory: g<InventoryRepository>(),
        units: g<UnitRepository>(),
        settings: g<SettingsRepository>(),
        recordOpeningStock: g<RecordOpeningStock>(),
        adjustStock: g<AdjustStock>(),
      ),
    )
    ..registerFactory(
      () => ReconciliationCubit(
        reconcile: g<ReconcileInventory>(),
        repair: g<RepairInventoryBalances>(),
      ),
    )
    ..registerFactory(
      () => CustomerBloc(
        repository: g<CustomerRepository>(),
        archiveCustomer: g<ArchiveCustomer>(),
        restoreCustomer: g<RestoreCustomer>(),
      ),
    )
    ..registerFactory(
      () => CustomerFormCubit(
        repository: g<CustomerRepository>(),
        settings: g<SettingsRepository>(),
        createCustomer: g<CreateCustomer>(),
        updateCustomer: g<UpdateCustomer>(),
      ),
    )
    ..registerFactory(
      () => CustomerDetailCubit(
        repository: g<CustomerRepository>(),
        archiveCustomer: g<ArchiveCustomer>(),
        restoreCustomer: g<RestoreCustomer>(),
        getReceivable: g<GetCustomerReceivable>(),
      ),
    )
    ..registerFactory(
      () => SupplierBloc(
        repository: g<SupplierRepository>(),
        archiveSupplier: g<ArchiveSupplier>(),
        restoreSupplier: g<RestoreSupplier>(),
      ),
    )
    ..registerFactory(
      () => SupplierFormCubit(
        repository: g<SupplierRepository>(),
        settings: g<SettingsRepository>(),
        createSupplier: g<CreateSupplier>(),
        updateSupplier: g<UpdateSupplier>(),
      ),
    )
    ..registerFactory(
      () => SupplierDetailCubit(
        repository: g<SupplierRepository>(),
        archiveSupplier: g<ArchiveSupplier>(),
        restoreSupplier: g<RestoreSupplier>(),
        getPayable: g<GetSupplierPayable>(),
      ),
    )
    ..registerFactory(
      () => PurchaseBloc(
        purchases: g<PurchaseRepository>(),
        settings: g<SettingsRepository>(),
      ),
    )
    ..registerFactory(
      () => PurchaseFormCubit(
        purchases: g<PurchaseRepository>(),
        suppliers: g<SupplierRepository>(),
        products: g<ProductRepository>(),
        units: g<UnitRepository>(),
        settings: g<SettingsRepository>(),
        lineBuilder: g<PurchaseLineBuilder>(),
        saveDraft: g<SavePurchaseDraft>(),
      ),
    )
    ..registerFactory(
      () => PurchaseDetailCubit(
        purchases: g<PurchaseRepository>(),
        settings: g<SettingsRepository>(),
        transition: g<TransitionPurchase>(),
        post: g<PostPurchase>(),
        voidPurchase: g<VoidPurchase>(),
      ),
    )
    ..registerFactory(
      () => SalesBloc(
        sales: g<SalesRepository>(),
        settings: g<SettingsRepository>(),
      ),
    )
    ..registerFactory(
      () => SalesFormCubit(
        sales: g<SalesRepository>(),
        customers: g<CustomerRepository>(),
        products: g<ProductRepository>(),
        units: g<UnitRepository>(),
        settings: g<SettingsRepository>(),
        lineBuilder: g<SalesLineBuilder>(),
        stockCheck: g<SalesStockCheck>(),
        saveDraft: g<SaveSalesDraft>(),
      ),
    )
    ..registerFactory(
      () => SalesDetailCubit(
        sales: g<SalesRepository>(),
        settings: g<SettingsRepository>(),
        transition: g<TransitionSale>(),
        post: g<PostSale>(),
        voidSale: g<VoidSale>(),
        shareInvoice: g<ShareInvoicePdf>(),
      ),
    )
    ..registerFactory(() => ReturnsBloc(returns: g<ReturnRepository>()))
    ..registerFactory(() => ReturnDetailCubit(returns: g<ReturnRepository>()))
    ..registerFactory(() => InvoiceReturnsCubit(returns: g<ReturnRepository>()))
    ..registerFactory(
      () => ReturnFormCubit(
        loader: g<ReturnableInvoiceLoader>(),
        methods: g<PaymentMethodRepository>(),
        postReturn: g<PostReturn>(),
        ids: g<IdGenerator>(),
      ),
    )
    ..registerFactory(() => PaymentsBloc(payments: g<PaymentRepository>()))
    ..registerFactory(
      () => PaymentFormCubit(
        parties: g<PartyDirectory>(),
        methods: g<PaymentMethodRepository>(),
        openInvoices: g<GetOpenInvoices>(),
        recordPayment: g<RecordPayment>(),
        settings: g<SettingsRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
        preferences: g<PreferencesRepository>(),
      ),
    )
    ..registerFactory(
      () => PaymentDetailCubit(
        payments: g<PaymentRepository>(),
        openInvoices: g<GetOpenInvoices>(),
        reversePayment: g<ReversePayment>(),
        recordRefund: g<RecordRefund>(),
        allocateCredit: g<AllocatePaymentCredit>(),
        settings: g<SettingsRepository>(),
        ids: g<IdGenerator>(),
        clock: g<Clock>(),
      ),
    )
    ..registerFactory(() => OutstandingCubit(getBalance: g<GetPartyBalance>()))
    ..registerFactory(() => PartyBalanceCubit(getBalance: g<GetPartyBalance>()))
    ..registerFactory(
      () => InvoiceSettlementCubit(openInvoices: g<GetOpenInvoices>()),
    )
    ..registerFactory(
      () => PaymentMethodsCubit(
        methods: g<PaymentMethodRepository>(),
        createMethod: g<CreatePaymentMethod>(),
        setArchived: g<SetPaymentMethodArchived>(),
        preferences: g<PreferencesRepository>(),
        updatePreferences: g<UpdatePreferences>(),
      ),
    )
    ..registerFactory(
      () => ExpensesBloc(
        expenses: g<ExpenseRepository>(),
        categories: g<ExpenseCategoryRepository>(),
        settings: g<SettingsRepository>(),
      ),
    )
    ..registerFactory(
      () => ExpenseFormCubit(
        expenses: g<ExpenseRepository>(),
        categories: g<ExpenseCategoryRepository>(),
        methods: g<PaymentMethodRepository>(),
        taxRates: g<TaxRateRepository>(),
        settings: g<SettingsRepository>(),
        saveDraft: g<SaveExpenseDraft>(),
        postExpense: g<PostExpense>(),
        clock: g<Clock>(),
        preferences: g<PreferencesRepository>(),
      ),
    )
    ..registerFactory(
      () => ExpenseDetailCubit(
        expenses: g<ExpenseRepository>(),
        post: g<PostExpense>(),
        cancel: g<CancelExpense>(),
        voidExpense: g<VoidExpense>(),
        addAttachment: g<AddExpenseAttachment>(),
        removeAttachment: g<RemoveExpenseAttachment>(),
      ),
    )
    ..registerFactory(
      () => ExpenseCategoriesCubit(
        categories: g<ExpenseCategoryRepository>(),
        createCategory: g<CreateExpenseCategory>(),
        updateCategory: g<UpdateExpenseCategory>(),
        setArchived: g<SetExpenseCategoryArchived>(),
      ),
    )
    ..registerFactory(
      () => ExpenseReportCubit(
        expenses: g<ExpenseRepository>(),
        categories: g<ExpenseCategoryRepository>(),
        clock: g<Clock>(),
      ),
    )
    ..registerFactory(
      () => DashboardBloc(getDashboard: g<GetDashboard>(), clock: g<Clock>()),
    )
    ..registerFactory(
      () => ReportBloc(
        buildReport: g<BuildReport>(),
        exportReport: g<ExportReportCsv>(),
        options: g<ReportFilterOptions>(),
        clock: g<Clock>(),
      ),
    )
    ..registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(
        preferences: g<PreferencesRepository>(),
        business: g<BusinessProfileRepository>(),
        currencies: g<CurrencyRepository>(),
        settings: g<SettingsRepository>(),
        numbering: g<NumberingRepository>(),
        logos: g<LogoStorage>(),
        saveBusinessProfile: g<SaveBusinessProfile>(),
        changeCurrency: g<ChangeCurrency>(),
        updatePreferences: g<UpdatePreferences>(),
        saveNumbering: g<SaveNumbering>(),
        setNextDocumentNumber: g<SetNextDocumentNumber>(),
      ),
      dispose: (cubit) => cubit.close(),
    )
    ..registerFactory(
      () => ProductTaxCubit(
        products: g<ProductRepository>(),
        tax: g<TaxRepository>(),
        classifications: g<ProductClassificationRepository>(),
        setTreatment: g<SetProductTaxTreatment>(),
        add: g<AddProductClassification>(),
        update: g<UpdateProductClassification>(),
        remove: g<RemoveProductClassification>(),
        setPrimary: g<SetPrimaryProductClassification>(),
      ),
    )
    ..registerFactory(
      () => TaxSettingsCubit(
        read: g<TaxRepository>(),
        preferences: g<TaxPreferencesRepository>(),
        settings: g<SettingsRepository>(),
        editor: g<TaxConfigEditor>(),
      ),
    )
    ..registerFactory(
      () => AuditCenterCubit(
        queries: g<AuditQueryRepository>(),
        exports: g<ListExportHistory>(),
        operators: g<AuditOperatorRepository>(),
        saveOperator: g<SaveAuditOperatorName>(),
      ),
    )
    ..registerFactory(
      () => AuditLogCubit(queries: g<AuditQueryRepository>()),
    )
    ..registerFactory(
      () => AuditEventCubit(
        queries: g<AuditQueryRepository>(),
        hasher: g<AuditHasher>(),
      ),
    )
    ..registerFactory(
      () => AuditIntegrityCubit(
        verify: g<VerifyAuditChain>(),
        createCheckpoint: g<CreateAuditCheckpoint>(),
        clock: g<Clock>(),
      ),
    )
    ..registerFactoryParam<ExportListCubit, String?, void>(
      (only, _) => ExportListCubit(
        list: g<ListExportHistory>(),
        history: g<ExportHistoryRepository>(),
        verify: g<VerifyExportFile>(),
        share: g<ShareExportFile>(),
        deleteFile: g<DeleteExportFile>(),
        only: only,
      ),
    )
    ..registerFactory(
      () => TaxRatesCubit(
        taxRates: g<TaxRateRepository>(),
        preferences: g<PreferencesRepository>(),
        createTaxRate: g<CreateTaxRate>(),
        updateTaxRate: g<UpdateTaxRate>(),
        setArchived: g<SetTaxRateArchived>(),
        setDefault: g<SetDefaultTaxRate>(),
        updatePreferences: g<UpdatePreferences>(),
      ),
    );
}
