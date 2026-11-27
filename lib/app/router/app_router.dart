import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/features/taxation/presentation/bloc/tax_settings_cubit.dart';
import 'package:inventrix/features/taxation/presentation/pages/tax_list_page.dart';
import 'package:inventrix/features/taxation/presentation/pages/tax_rule_page.dart';
import 'package:inventrix/features/taxation/presentation/pages/tax_settings_page.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/products/presentation/bloc/product_tax_cubit.dart';
import 'package:inventrix/features/products/presentation/pages/product_tax_page.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_center_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_event_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_integrity_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_log_cubit.dart';
import 'package:inventrix/features/audit/presentation/pages/audit_center_page.dart';
import 'package:inventrix/features/audit/presentation/pages/audit_event_page.dart';
import 'package:inventrix/features/audit/presentation/pages/audit_integrity_page.dart';
import 'package:inventrix/features/audit/presentation/pages/audit_log_page.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/generate_auditor_export.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_history_cubit.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_wizard_cubit.dart';
import 'package:inventrix/features/auditor_exports/presentation/pages/export_detail_page.dart';
import 'package:inventrix/features/auditor_exports/presentation/pages/export_history_page.dart';
import 'package:inventrix/features/auditor_exports/presentation/pages/export_wizard_page.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_preset.dart';
import 'package:inventrix/app/router/more_destinations.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/shell/app_shell.dart';
import 'package:inventrix/app/shell/coming_soon_page.dart';
import 'package:inventrix/app/shell/more_page.dart';
import 'package:inventrix/app/shell/not_found_page.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/features/backup/presentation/pages/backup_page.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_cubit.dart';
import 'package:inventrix/features/categories/presentation/pages/categories_page.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_bloc.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_detail_cubit.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_event.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_form_cubit.dart';
import 'package:inventrix/features/customers/presentation/pages/customer_detail_page.dart';
import 'package:inventrix/features/customers/presentation/pages/customer_form_page.dart';
import 'package:inventrix/features/customers/presentation/pages/customers_page.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:inventrix/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_categories_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_detail_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_form_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_report_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_categories_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_detail_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_form_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_report_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expenses_page.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/onboarding/presentation/pages/intro_page.dart';
import 'package:inventrix/features/onboarding/presentation/pages/setup_page.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:inventrix/features/inventory/presentation/bloc/reconciliation_cubit.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_detail_cubit.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_operation_cubit.dart';
import 'package:inventrix/features/inventory/presentation/pages/inventory_page.dart';
import 'package:inventrix/features/inventory/presentation/pages/reconciliation_page.dart';
import 'package:inventrix/features/inventory/presentation/pages/stock_detail_page.dart';
import 'package:inventrix/features/inventory/presentation/pages/stock_operation_page.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_detail_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_form_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_methods_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:inventrix/features/payments/presentation/pages/outstanding_page.dart';
import 'package:inventrix/features/payments/presentation/pages/payment_detail_page.dart';
import 'package:inventrix/features/payments/presentation/pages/payment_form_page.dart';
import 'package:inventrix/features/payments/presentation/pages/payment_methods_page.dart';
import 'package:inventrix/features/payments/presentation/pages/payments_page.dart';
import 'package:inventrix/features/products/presentation/bloc/product_bloc.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_event.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/unit_cubit.dart';
import 'package:inventrix/features/products/presentation/pages/product_detail_page.dart';
import 'package:inventrix/features/products/presentation/pages/product_form_page.dart';
import 'package:inventrix/features/products/presentation/pages/products_page.dart';
import 'package:inventrix/features/products/presentation/pages/units_page.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_bloc.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_detail_cubit.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_event.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_form_cubit.dart';
import 'package:inventrix/features/purchases/presentation/pages/purchase_detail_page.dart';
import 'package:inventrix/features/purchases/presentation/pages/purchase_form_page.dart';
import 'package:inventrix/features/purchases/presentation/pages/purchases_page.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_bloc.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_event.dart';
import 'package:inventrix/features/reports/presentation/pages/report_page.dart';
import 'package:inventrix/features/reports/presentation/pages/reports_page.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_detail_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_form_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/returns_bloc.dart';
import 'package:inventrix/features/returns/presentation/pages/return_detail_page.dart';
import 'package:inventrix/features/returns/presentation/pages/return_form_page.dart';
import 'package:inventrix/features/returns/presentation/pages/returns_page.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_event.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_form_cubit.dart';
import 'package:inventrix/features/sales/presentation/pages/sales_detail_page.dart';
import 'package:inventrix/features/sales/presentation/pages/sales_form_page.dart';
import 'package:inventrix/features/sales/presentation/pages/sales_page.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/features/settings/presentation/bloc/tax_rates_cubit.dart';
import 'package:inventrix/features/settings/presentation/pages/business_profile_page.dart';
import 'package:inventrix/features/settings/presentation/pages/numbering_page.dart';
import 'package:inventrix/features/settings/presentation/pages/regional_settings_page.dart';
import 'package:inventrix/features/settings/presentation/pages/settings_page.dart';
import 'package:inventrix/features/settings/presentation/pages/tax_rates_page.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_bloc.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_detail_cubit.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_event.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_form_cubit.dart';
import 'package:inventrix/features/suppliers/presentation/pages/supplier_detail_page.dart';
import 'package:inventrix/features/suppliers/presentation/pages/supplier_form_page.dart';
import 'package:inventrix/features/suppliers/presentation/pages/suppliers_page.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Builds the application [GoRouter].
abstract final class AppRouter {
  static const Set<String> _implementedMore = {
    RouteNames.customers,
    RouteNames.suppliers,
    RouteNames.purchases,
    RouteNames.payments,
    RouteNames.returns,
    RouteNames.expenses,
    RouteNames.reports,
    RouteNames.backup,
    RouteNames.audit,
    RouteNames.tax,
    RouteNames.settings,
  };

  /// Company details are mandatory: until a business profile exists, every
  /// location except the introduction and the first-time setup is sent to
  /// the setup (or to the introduction first, if it was never seen). Once the
  /// profile exists, the setup screens are no longer reachable.
  static String? _setupRedirect(GetIt di, GoRouterState state) {
    if (!di.isRegistered<SettingsCubit>()) {
      return null;
    }
    final settings = di<SettingsCubit>().state;
    // Only act on settings that were really loaded: a failed load must not
    // lock the owner out.
    if (settings.status != ViewStatus.loaded) {
      return null;
    }
    final path = state.uri.path;
    final onSetup =
        path == RoutePaths.setup || path.startsWith('${RoutePaths.setup}/');
    if (settings.business != null) {
      return onSetup ? RoutePaths.dashboard : null;
    }
    if (onSetup || path == RoutePaths.intro) {
      return null;
    }
    return settings.preferences.introSeen
        ? RoutePaths.setup
        : RoutePaths.intro;
  }

  /// Creates a router. There is no login: the dashboard opens directly once
  /// the company details exist (see [_setupRedirect]).
  ///
  /// Screens obtain their BLoCs from [locator] (default: `GetIt.instance`).
  static GoRouter create({
    String initialLocation = RoutePaths.dashboard,
    List<NavigatorObserver>? observers,
    GetIt? locator,
  }) {
    final di = locator ?? GetIt.instance;
    String id(GoRouterState state) => state.pathParameters['id']!;

    return GoRouter(
      initialLocation: initialLocation,
      observers: observers,
      redirect: (context, state) => _setupRedirect(di, state),
      errorBuilder: (context, state) =>
          NotFoundPage(location: state.uri.toString()),
      routes: [
        GoRoute(path: '/', redirect: (context, state) => RoutePaths.dashboard),
        GoRoute(
          path: RoutePaths.intro,
          name: RouteNames.intro,
          builder: (context, state) => const IntroPage(),
        ),
        GoRoute(
          path: RoutePaths.setup,
          name: RouteNames.setup,
          builder: (context, state) => BlocProvider(
            create: (_) => di<BackupBloc>(),
            child: const SetupPage(),
          ),
          routes: [
            GoRoute(
              path: 'company',
              name: RouteNames.setupCompany,
              builder: (context, state) =>
                  const BusinessProfilePage(isSetup: true),
            ),
          ],
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.dashboard,
                  name: RouteNames.dashboard,
                  builder: (context, state) => BlocProvider(
                    create: (_) =>
                        di<DashboardBloc>()..add(const DashboardStarted()),
                    child: const DashboardPage(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.products,
                  name: RouteNames.products,
                  builder: (context, state) => BlocProvider(
                    create: (_) =>
                        di<ProductBloc>()..add(const ProductsStarted()),
                    child: const ProductsPage(),
                  ),
                  routes: [
                    // Static segments must come before ':id'.
                    GoRoute(
                      path: 'new',
                      name: RouteNames.productNew,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<ProductFormCubit>()..load(),
                        child: const ProductFormPage(),
                      ),
                    ),
                    GoRoute(
                      path: 'categories',
                      name: RouteNames.categories,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<CategoryCubit>()..load(),
                        child: const CategoriesPage(),
                      ),
                    ),
                    GoRoute(
                      path: 'units',
                      name: RouteNames.units,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<UnitCubit>()..load(),
                        child: const UnitsPage(),
                      ),
                    ),
                    GoRoute(
                      path: ':id',
                      name: RouteNames.productDetail,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<ProductDetailCubit>()..load(id(state)),
                        child: ProductDetailPage(productId: id(state)),
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          name: RouteNames.productEdit,
                          builder: (context, state) => BlocProvider(
                            create: (_) =>
                                di<ProductFormCubit>()
                                  ..load(productId: id(state)),
                            child: ProductFormPage(productId: id(state)),
                          ),
                        ),
                        GoRoute(
                          path: 'tax',
                          name: RouteNames.productTax,
                          builder: (context, state) => BlocProvider(
                            create: (_) =>
                                di<ProductTaxCubit>()..load(id(state)),
                            child: const ProductTaxPage(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.inventory,
                  name: RouteNames.inventory,
                  builder: (context, state) => BlocProvider(
                    create: (_) =>
                        di<InventoryBloc>()..add(const InventoryStarted()),
                    child: const InventoryPage(),
                  ),
                  routes: [
                    // Static segments must come before ':id'.
                    GoRoute(
                      path: 'low-stock',
                      name: RouteNames.lowStock,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di.get<InventoryBloc>(
                          param1: const StockFilter(
                            status: StockStatusFilter.lowOrOut,
                          ),
                        )..add(const InventoryStarted()),
                        child: const InventoryPage(
                          title: 'Low-stock report',
                          isReport: true,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'reconcile',
                      name: RouteNames.reconcile,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<ReconciliationCubit>()..run(),
                        child: const ReconciliationPage(),
                      ),
                    ),
                    GoRoute(
                      path: ':id',
                      name: RouteNames.stockDetail,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<StockDetailCubit>()..load(id(state)),
                        child: StockDetailPage(productId: id(state)),
                      ),
                      routes: [
                        for (final entry in {
                          'opening': (
                            RouteNames.stockOpening,
                            StockOperation.opening,
                          ),
                          'in': (RouteNames.stockIn, StockOperation.stockIn),
                          'out': (RouteNames.stockOut, StockOperation.stockOut),
                        }.entries)
                          GoRoute(
                            path: entry.key,
                            name: entry.value.$1,
                            builder: (context, state) => BlocProvider(
                              create: (_) =>
                                  di<StockOperationCubit>()
                                    ..load(id(state), entry.value.$2),
                              child: StockOperationPage(
                                productId: id(state),
                                operation: entry.value.$2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.sales,
                  name: RouteNames.sales,
                  builder: (context, state) => BlocProvider(
                    create: (_) => di<SalesBloc>()..add(const SalesStarted()),
                    child: const SalesPage(),
                  ),
                  routes: [
                    // Static segments must come before ':id'.
                    GoRoute(
                      path: 'new',
                      name: RouteNames.saleNew,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<SalesFormCubit>()..load(),
                        child: const SalesFormPage(),
                      ),
                    ),
                    GoRoute(
                      path: ':id',
                      name: RouteNames.saleDetail,
                      builder: (context, state) => MultiBlocProvider(
                        providers: [
                          BlocProvider(
                            create: (_) =>
                                di<SalesDetailCubit>()..load(id(state)),
                          ),
                          BlocProvider(
                            create: (_) =>
                                di<InvoiceSettlementCubit>()
                                  ..load(InvoiceKind.sales, id(state)),
                          ),
                          BlocProvider(
                            create: (_) =>
                                di<InvoiceReturnsCubit>()
                                  ..load(InvoiceKind.sales, id(state)),
                          ),
                        ],
                        child: SalesDetailPage(saleId: id(state)),
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          name: RouteNames.saleEdit,
                          builder: (context, state) => BlocProvider(
                            create: (_) =>
                                di<SalesFormCubit>()..load(saleId: id(state)),
                            child: SalesFormPage(saleId: id(state)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RoutePaths.more,
                  name: RouteNames.more,
                  builder: (context, state) => const MorePage(),
                  routes: [
                    for (final destination in moreDestinations)
                      if (!_implementedMore.contains(destination.name))
                        GoRoute(
                          path: RoutePaths.relativeTo(
                            destination.path,
                            RoutePaths.more,
                          ),
                          name: destination.name,
                          builder: (context, state) => ComingSoonPage(
                            title: destination.title,
                            icon: destination.icon,
                            phase: destination.phase,
                          ),
                        ),
                    GoRoute(
                      path: 'settings',
                      name: RouteNames.settings,
                      builder: (context, state) => const SettingsPage(),
                      routes: [
                        GoRoute(
                          path: 'business',
                          name: RouteNames.settingsBusiness,
                          builder: (context, state) =>
                              const BusinessProfilePage(),
                        ),
                        GoRoute(
                          path: 'regional',
                          name: RouteNames.settingsRegional,
                          builder: (context, state) =>
                              const RegionalSettingsPage(),
                        ),
                        GoRoute(
                          path: 'numbering',
                          name: RouteNames.settingsNumbering,
                          builder: (context, state) => const NumberingPage(),
                        ),
                        GoRoute(
                          path: 'tax-rates',
                          name: RouteNames.taxRates,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<TaxRatesCubit>()..load(),
                            child: const TaxRatesPage(),
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'tax',
                      name: RouteNames.tax,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<TaxSettingsCubit>()..load(),
                        child: const TaxSettingsPage(),
                      ),
                      routes: [
                        _taxList(di, 'systems', RouteNames.taxSystems, TaxListKind.systems),
                        _taxList(di, 'places', RouteNames.taxPlaces, TaxListKind.places),
                        _taxList(di, 'profiles', RouteNames.taxProfiles, TaxListKind.profiles),
                        _taxList(di, 'categories', RouteNames.taxCategories, TaxListKind.categories),
                        _taxList(di, 'overrides', RouteNames.taxOverrides, TaxListKind.overrides),
                        GoRoute(
                          path: 'rules',
                          name: RouteNames.taxRules,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<TaxSettingsCubit>()..load(),
                            child: const TaxListPage(kind: TaxListKind.rules),
                          ),
                          routes: [
                            GoRoute(
                              path: ':id',
                              name: RouteNames.taxRule,
                              builder: (context, state) => BlocProvider(
                                create: (_) => di<TaxSettingsCubit>()..load(),
                                child: TaxRulePage(ruleId: state.pathParameters['id']!),
                              ),
                            ),
                          ],
                        ),
                        GoRoute(
                          path: 'preferences',
                          name: RouteNames.taxPreferences,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<TaxSettingsCubit>()..load(),
                            child: const TaxPreferencesPage(),
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'audit',
                      name: RouteNames.audit,
                      builder: (context, state) => BlocProvider(
                        create: (_) => di<AuditCenterCubit>()..load(),
                        child: const AuditCenterPage(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'log',
                          name: RouteNames.auditLog,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<AuditLogCubit>()..load(),
                            child: const AuditLogPage(),
                          ),
                        ),
                        GoRoute(
                          path: 'event/:id',
                          name: RouteNames.auditEvent,
                          builder: (context, state) {
                            final id = state.pathParameters['id']!;
                            return BlocProvider(
                              create: (_) => di<AuditEventCubit>()..load(id),
                              child: AuditEventPage(eventId: id),
                            );
                          },
                        ),
                        GoRoute(
                          path: 'integrity',
                          name: RouteNames.auditIntegrity,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<AuditIntegrityCubit>(),
                            child: const AuditIntegrityPage(),
                          ),
                        ),
                        GoRoute(
                          path: 'export',
                          name: RouteNames.auditExport,
                          builder: (context, state) {
                            final extra = state.extra;
                            return BlocProvider(
                              create: (_) => ExportWizardCubit(
                                generate: di<GenerateAuditorExport>(),
                                clock: di<Clock>(),
                                preset: extra is ExportPreset ? extra : null,
                              ),
                              child: const ExportWizardPage(),
                            );
                          },
                        ),
                        GoRoute(
                          path: 'exports',
                          name: RouteNames.auditExports,
                          builder: (context, state) => BlocProvider(
                            create: (_) =>
                                di<ExportListCubit>(param1: null)..load(),
                            child: const ExportHistoryPage(),
                          ),
                          routes: [
                            GoRoute(
                              path: ':id',
                              name: RouteNames.auditExportDetail,
                              builder: (context, state) => BlocProvider(
                                create: (_) => di<ExportListCubit>(
                                  param1: state.pathParameters['id'],
                                )..load(),
                                child: const ExportDetailPage(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'backup',
                      name: RouteNames.backup,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<BackupBloc>()..add(const BackupStarted()),
                        child: BlocBuilder<SettingsCubit, SettingsState>(
                          buildWhen: (a, b) =>
                              a.preferences.backupReminderDays !=
                              b.preferences.backupReminderDays,
                          builder: (context, settings) => BackupPage(
                            reminderDays:
                                settings.preferences.backupReminderDays,
                          ),
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'purchases',
                      name: RouteNames.purchases,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<PurchaseBloc>()..add(const PurchasesStarted()),
                        child: const PurchasesPage(),
                      ),
                      routes: [
                        // Static segments must come before ':id'.
                        GoRoute(
                          path: 'new',
                          name: RouteNames.purchaseNew,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<PurchaseFormCubit>()..load(),
                            child: const PurchaseFormPage(),
                          ),
                        ),
                        GoRoute(
                          path: ':id',
                          name: RouteNames.purchaseDetail,
                          builder: (context, state) => MultiBlocProvider(
                            providers: [
                              BlocProvider(
                                create: (_) =>
                                    di<PurchaseDetailCubit>()..load(id(state)),
                              ),
                              BlocProvider(
                                create: (_) =>
                                    di<InvoiceSettlementCubit>()
                                      ..load(InvoiceKind.purchase, id(state)),
                              ),
                              BlocProvider(
                                create: (_) =>
                                    di<InvoiceReturnsCubit>()
                                      ..load(InvoiceKind.purchase, id(state)),
                              ),
                            ],
                            child: PurchaseDetailPage(purchaseId: id(state)),
                          ),
                          routes: [
                            GoRoute(
                              path: 'edit',
                              name: RouteNames.purchaseEdit,
                              builder: (context, state) => BlocProvider(
                                create: (_) =>
                                    di<PurchaseFormCubit>()
                                      ..load(purchaseId: id(state)),
                                child: PurchaseFormPage(purchaseId: id(state)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'payments',
                      name: RouteNames.payments,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<PaymentsBloc>()..add(const PaymentsStarted()),
                        child: const PaymentsPage(),
                      ),
                      routes: [
                        // Static segments must come before ':id'.
                        GoRoute(
                          path: 'new',
                          name: RouteNames.paymentNew,
                          builder: (context, state) {
                            final type =
                                state.uri.queryParameters['type'] == 'supplier'
                                ? PartyType.supplier
                                : PartyType.customer;
                            return BlocProvider(
                              create: (_) => di<PaymentFormCubit>()
                                ..load(
                                  type: type,
                                  partyId: state.uri.queryParameters['party'],
                                  invoiceId:
                                      state.uri.queryParameters['invoice'],
                                ),
                              child: PaymentFormPage(type: type),
                            );
                          },
                        ),
                        GoRoute(
                          path: 'outstanding',
                          name: RouteNames.paymentOutstanding,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<OutstandingCubit>()..load(),
                            child: const OutstandingPage(),
                          ),
                        ),
                        GoRoute(
                          path: 'methods',
                          name: RouteNames.paymentMethods,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<PaymentMethodsCubit>()..load(),
                            child: const PaymentMethodsPage(),
                          ),
                        ),
                        GoRoute(
                          path: ':id',
                          name: RouteNames.paymentDetail,
                          builder: (context, state) => BlocProvider(
                            create: (_) =>
                                di<PaymentDetailCubit>()..load(id(state)),
                            child: PaymentDetailPage(paymentId: id(state)),
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'reports',
                      name: RouteNames.reports,
                      builder: (context, state) => const ReportsPage(),
                      routes: [
                        GoRoute(
                          path: ':kind',
                          name: RouteNames.reportView,
                          builder: (context, state) {
                            final kind = ReportKind.fromSlug(
                              state.pathParameters['kind']!,
                            );
                            if (kind == null) {
                              return NotFoundPage(
                                location: state.uri.toString(),
                              );
                            }
                            return BlocProvider(
                              create: (_) =>
                                  di<ReportBloc>()..add(ReportStarted(kind)),
                              child: ReportPage(kind: kind),
                            );
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'expenses',
                      name: RouteNames.expenses,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<ExpensesBloc>()..add(const ExpensesStarted()),
                        child: const ExpensesPage(),
                      ),
                      routes: [
                        // Static segments must come before ':id'.
                        GoRoute(
                          path: 'new',
                          name: RouteNames.expenseNew,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<ExpenseFormCubit>()..load(),
                            child: const ExpenseFormPage(),
                          ),
                        ),
                        GoRoute(
                          path: 'categories',
                          name: RouteNames.expenseCategories,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<ExpenseCategoriesCubit>()..load(),
                            child: const ExpenseCategoriesPage(),
                          ),
                        ),
                        GoRoute(
                          path: 'report',
                          name: RouteNames.expenseReport,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<ExpenseReportCubit>()..load(),
                            child: const ExpenseReportPage(),
                          ),
                        ),
                        GoRoute(
                          path: ':id',
                          name: RouteNames.expenseDetail,
                          builder: (context, state) => BlocProvider(
                            create: (_) =>
                                di<ExpenseDetailCubit>()..load(id(state)),
                            child: ExpenseDetailPage(expenseId: id(state)),
                          ),
                          routes: [
                            GoRoute(
                              path: 'edit',
                              name: RouteNames.expenseEdit,
                              builder: (context, state) => BlocProvider(
                                create: (_) =>
                                    di<ExpenseFormCubit>()
                                      ..load(expenseId: id(state)),
                                child: ExpenseFormPage(expenseId: id(state)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'returns',
                      name: RouteNames.returns,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<ReturnsBloc>()..add(const ReturnsStarted()),
                        child: const ReturnsPage(),
                      ),
                      routes: [
                        // Static segments must come before ':kind/:id'.
                        GoRoute(
                          path: 'new',
                          name: RouteNames.returnNew,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<ReturnFormCubit>()
                              ..load(
                                kind:
                                    state.uri.queryParameters['kind'] ==
                                        'purchase'
                                    ? InvoiceKind.purchase
                                    : InvoiceKind.sales,
                                invoiceId: state.uri.queryParameters['invoice'],
                              ),
                            child: const ReturnFormPage(),
                          ),
                        ),
                        GoRoute(
                          path: ':kind/:id',
                          name: RouteNames.returnDetail,
                          builder: (context, state) {
                            final kind =
                                state.pathParameters['kind'] == 'purchase'
                                ? InvoiceKind.purchase
                                : InvoiceKind.sales;
                            return BlocProvider(
                              create: (_) =>
                                  di<ReturnDetailCubit>()
                                    ..load(kind, id(state)),
                              child: ReturnDetailPage(
                                kind: kind,
                                returnId: id(state),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'customers',
                      name: RouteNames.customers,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<CustomerBloc>()..add(const CustomersStarted()),
                        child: const CustomersPage(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'new',
                          name: RouteNames.customerNew,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<CustomerFormCubit>()..load(),
                            child: const CustomerFormPage(),
                          ),
                        ),
                        GoRoute(
                          path: ':id',
                          name: RouteNames.customerDetail,
                          builder: (context, state) => MultiBlocProvider(
                            providers: [
                              BlocProvider(
                                create: (_) =>
                                    di<CustomerDetailCubit>()..load(id(state)),
                              ),
                              BlocProvider(
                                create: (_) =>
                                    di<PartyBalanceCubit>()
                                      ..load(PartyType.customer, id(state)),
                              ),
                            ],
                            child: CustomerDetailPage(customerId: id(state)),
                          ),
                          routes: [
                            GoRoute(
                              path: 'edit',
                              name: RouteNames.customerEdit,
                              builder: (context, state) => BlocProvider(
                                create: (_) =>
                                    di<CustomerFormCubit>()
                                      ..load(customerId: id(state)),
                                child: CustomerFormPage(customerId: id(state)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'suppliers',
                      name: RouteNames.suppliers,
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            di<SupplierBloc>()..add(const SuppliersStarted()),
                        child: const SuppliersPage(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'new',
                          name: RouteNames.supplierNew,
                          builder: (context, state) => BlocProvider(
                            create: (_) => di<SupplierFormCubit>()..load(),
                            child: const SupplierFormPage(),
                          ),
                        ),
                        GoRoute(
                          path: ':id',
                          name: RouteNames.supplierDetail,
                          builder: (context, state) => MultiBlocProvider(
                            providers: [
                              BlocProvider(
                                create: (_) =>
                                    di<SupplierDetailCubit>()..load(id(state)),
                              ),
                              BlocProvider(
                                create: (_) =>
                                    di<PartyBalanceCubit>()
                                      ..load(PartyType.supplier, id(state)),
                              ),
                            ],
                            child: SupplierDetailPage(supplierId: id(state)),
                          ),
                          routes: [
                            GoRoute(
                              path: 'edit',
                              name: RouteNames.supplierEdit,
                              builder: (context, state) => BlocProvider(
                                create: (_) =>
                                    di<SupplierFormCubit>()
                                      ..load(supplierId: id(state)),
                                child: SupplierFormPage(supplierId: id(state)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

GoRoute _taxList(GetIt di, String path, String name, TaxListKind kind) => GoRoute(
  path: path,
  name: name,
  builder: (context, state) => BlocProvider(
    create: (_) => di<TaxSettingsCubit>()..load(),
    child: TaxListPage(kind: kind),
  ),
);
