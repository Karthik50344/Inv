import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/dashboard/domain/usecases/get_dashboard.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:inventrix/features/reports/data/repositories/drift_report_repository.dart';
import 'package:inventrix/features/reports/data/repositories/share_plus_report_exporter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_exporter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/features/reports/domain/usecases/build_report.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_bloc.dart';
import 'package:inventrix/features/expenses/data/repositories/drift_expense_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_categories_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_detail_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_form_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_report_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_detail_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_form_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:inventrix/features/sales/domain/usecases/void_sale.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/di/injection.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/categories/data/repositories/drift_category_repository.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_cubit.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/features/products/data/repositories/drift_product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_bloc.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_bloc.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_bloc.dart';

void main() {
  late GetIt locator;

  setUp(() {
    locator = GetIt.asNewInstance();
  });

  tearDown(() async => resetDependencies(locator: locator));

  test('resolves all registered dependencies', () async {
    await configureDependencies(
      locator: locator,
      database: AppDatabase(NativeDatabase.memory()),
    );
    expect(locator<AppDatabase>(), isA<AppDatabase>());
    expect(locator<TransactionRunner>(), isA<DriftTransactionRunner>());
    expect(locator<GoRouter>(), isA<GoRouter>());
    expect(locator<Clock>(), isA<Clock>());
    expect(
      locator<IdGenerator>().newId(),
      isNot(locator<IdGenerator>().newId()),
    );
  });

  test('resolves repositories, use cases and BLoCs', () async {
    await configureDependencies(
      locator: locator,
      database: AppDatabase(NativeDatabase.memory()),
    );
    expect(locator<ProductRepository>(), isA<DriftProductRepository>());
    expect(locator<CategoryRepository>(), isA<DriftCategoryRepository>());
    expect(locator<CreateProduct>(), isA<CreateProduct>());
    expect(locator<CreateCustomer>(), isA<CreateCustomer>());
    // BLoCs are factories: each request yields a new instance.
    final a = locator<ProductBloc>();
    final b = locator<ProductBloc>();
    expect(identical(a, b), isFalse);
    expect(locator<CategoryCubit>(), isA<CategoryCubit>());
    expect(locator<SupplierBloc>(), isA<SupplierBloc>());
    expect(locator<PurchaseRepository>(), isA<PurchaseRepository>());
    expect(locator<PostPurchase>(), isA<PostPurchase>());
    final purchaseBloc = locator<PurchaseBloc>();
    expect(purchaseBloc, isA<PurchaseBloc>());
    await purchaseBloc.close();
    expect(locator<PaymentRepository>(), isA<PaymentRepository>());
    expect(
      identical(locator<PaymentRepository>(), locator<InvoicePaymentGuard>()),
      isTrue,
    );
    expect(locator<RecordPayment>(), isA<RecordPayment>());
    expect(locator<VoidSale>(), isA<VoidSale>());
    final paymentsBloc = locator<PaymentsBloc>();
    expect(paymentsBloc, isA<PaymentsBloc>());
    await paymentsBloc.close();
    await locator<PaymentFormCubit>().close();
    await locator<PaymentDetailCubit>().close();
    await locator<OutstandingCubit>().close();
    expect(locator<ExpenseRepository>(), isA<DriftExpenseRepository>());
    expect(locator<AttachmentStorage>(), isA<AttachmentStorage>());
    expect(locator<PostExpense>(), isA<PostExpense>());
    final expensesBloc = locator<ExpensesBloc>();
    expect(expensesBloc, isA<ExpensesBloc>());
    await expensesBloc.close();
    await locator<ExpenseFormCubit>().close();
    await locator<ExpenseDetailCubit>().close();
    await locator<ExpenseCategoriesCubit>().close();
    await locator<ExpenseReportCubit>().close();
    expect(locator<ReportRepository>(), isA<DriftReportRepository>());
    expect(locator<ReportExporter>(), isA<SharePlusReportExporter>());
    expect(locator<BuildReport>(), isA<BuildReport>());
    expect(locator<GetDashboard>(), isA<GetDashboard>());
    final dashboardBloc = locator<DashboardBloc>();
    expect(dashboardBloc, isA<DashboardBloc>());
    await dashboardBloc.close();
    await locator<ReportBloc>().close();
    await a.close();
    await b.close();
  });

  test('database and router are singletons', () async {
    await configureDependencies(
      locator: locator,
      database: AppDatabase(NativeDatabase.memory()),
    );
    expect(identical(locator<AppDatabase>(), locator<AppDatabase>()), isTrue);
    expect(identical(locator<GoRouter>(), locator<GoRouter>()), isTrue);
  });

  test('can be reset and configured again', () async {
    await configureDependencies(
      locator: locator,
      database: AppDatabase(NativeDatabase.memory()),
    );
    await locator<AppDatabase>().initialize();
    await resetDependencies(locator: locator);
    expect(locator.isRegistered<AppDatabase>(), isFalse);
    await configureDependencies(
      locator: locator,
      database: AppDatabase(NativeDatabase.memory()),
    );
    expect(locator.isRegistered<AppDatabase>(), isTrue);
  });
}
