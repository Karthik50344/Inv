import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';

/// A product, customer or supplier that can be picked as a report filter.
final class ReportOption extends Equatable {
  /// Creates an option.
  const ReportOption({required this.id, required this.name});

  /// Record id.
  final String id;

  /// Name shown in pickers and in the report header.
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Everything that can be picked in the report filters.
final class ReportFilterChoices extends Equatable {
  /// Creates the choices.
  const ReportFilterChoices({
    this.products = const [],
    this.customers = const [],
    this.suppliers = const [],
  });

  /// Products (archived ones included: they appear in old documents).
  final List<ReportOption> products;

  /// Customers (archived ones included).
  final List<ReportOption> customers;

  /// Suppliers (archived ones included).
  final List<ReportOption> suppliers;

  /// Name of the product [id], if known.
  String? productName(String? id) => _find(products, id);

  /// Name of the customer [id], if known.
  String? customerName(String? id) => _find(customers, id);

  /// Name of the supplier [id], if known.
  String? supplierName(String? id) => _find(suppliers, id);

  static String? _find(List<ReportOption> options, String? id) {
    if (id == null) {
      return null;
    }
    for (final option in options) {
      if (option.id == id) {
        return option.name;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [products, customers, suppliers];
}

/// Loads the choices of the report filters from the master data.
final class ReportFilterOptions {
  /// Creates the service.
  const ReportFilterOptions({
    required ProductRepository products,
    required PartyDirectory parties,
  }) : _products = products,
       _parties = parties;

  final ProductRepository _products;
  final PartyDirectory _parties;

  /// Loads products, customers and suppliers.
  Future<Result<ReportFilterChoices>> load() async {
    final products = await _products.search(
      const ProductFilter(includeArchived: true),
    );
    final productList = products.valueOrNull;
    if (productList == null) {
      return Result.failure(products.failureOrNull!);
    }
    final customers = await _parties.all(PartyType.customer);
    final customerList = customers.valueOrNull;
    if (customerList == null) {
      return Result.failure(customers.failureOrNull!);
    }
    final suppliers = await _parties.all(PartyType.supplier);
    final supplierList = suppliers.valueOrNull;
    if (supplierList == null) {
      return Result.failure(suppliers.failureOrNull!);
    }
    return Result.success(
      ReportFilterChoices(
        products: [
          for (final p in productList)
            ReportOption(id: p.id, name: '${p.name} (${p.sku})'),
        ],
        customers: [
          for (final c in customerList) ReportOption(id: c.id, name: c.name),
        ],
        suppliers: [
          for (final s in supplierList) ReportOption(id: s.id, name: s.name),
        ],
      ),
    );
  }
}
