import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Controllable clock.
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 1, 1, 10);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// Produces `id-1`, `id-2`, ...
class SequentialIds implements IdGenerator {
  int _n = 0;

  @override
  String newId() => 'id-${++_n}';
}

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([
    this.config = const CurrencyConfig(currencyCode: 'INR', decimalPlaces: 2),
  ]);

  CurrencyConfig config;

  /// Whether purchases need approval before posting.
  bool purchaseApprovalRequired = false;

  @override
  Future<Result<CurrencyConfig>> getCurrencyConfig() async =>
      Result.success(config);

  @override
  Future<Result<bool>> isPurchaseApprovalRequired() async =>
      Result.success(purchaseApprovalRequired);

  @override
  Future<Result<void>> setPurchaseApprovalRequired(bool value) async {
    purchaseApprovalRequired = value;
    return const Result.success(null);
  }

  /// Whether sales need approval before posting.
  bool salesApprovalRequired = false;

  /// Business identity returned for documents.
  BusinessProfile businessProfile = const BusinessProfile(
    name: 'Test Traders',
    address: '1 Market Road',
    phone: '555-0100',
  );

  @override
  Future<Result<bool>> isSalesApprovalRequired() async =>
      Result.success(salesApprovalRequired);

  @override
  Future<Result<void>> setSalesApprovalRequired(bool value) async {
    salesApprovalRequired = value;
    return const Result.success(null);
  }

  @override
  Future<Result<BusinessProfile>> getBusinessProfile() async =>
      Result.success(businessProfile);
}

Result<T> _notFound<T>(String what, String id) =>
    Result.failure(NotFoundFailure('$what $id not found'));

class FakeTaxRateRepository implements TaxRateRepository {
  final Map<String, TaxRate> items = {};

  @override
  Future<Result<List<TaxRate>>> list({bool includeArchived = false}) async {
    final all =
        items.values.where((t) => includeArchived || !t.isArchived).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Result.success(all);
  }

  @override
  Future<Result<TaxRate>> getById(String id) async =>
      items[id] == null ? _notFound('TaxRate', id) : Result.success(items[id]!);

  @override
  Future<Result<bool>> nameExists(String name) async => Result.success(
    items.values.any(
      (t) => !t.isArchived && t.name.toLowerCase() == name.toLowerCase(),
    ),
  );

  @override
  Future<Result<void>> create(TaxRate taxRate) async {
    items[taxRate.id] = taxRate;
    return const Result.success(null);
  }
}

class FakeProductRepository implements ProductRepository {
  final Map<String, Product> items = {};

  /// When set, `search` fails with this failure.
  Failure? searchFailure;

  @override
  Future<Result<List<Product>>> search(ProductFilter filter) async {
    if (searchFailure != null) {
      return Result.failure(searchFailure!);
    }
    final q = filter.query.toLowerCase();
    final list = items.values.where((p) {
      if (!filter.includeArchived && p.isArchived) {
        return false;
      }
      if (filter.categoryId != null && p.categoryId != filter.categoryId) {
        return false;
      }
      return q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    return Result.success(list);
  }

  @override
  Future<Result<Product>> getById(String id) async =>
      items[id] == null ? _notFound('Product', id) : Result.success(items[id]!);

  @override
  Future<Result<bool>> skuExists(String sku, {String? excludeId}) async =>
      Result.success(
        items.values.any((p) => p.sku == sku && p.id != excludeId),
      );

  @override
  Future<Result<bool>> barcodeExists(
    String barcode, {
    String? excludeId,
  }) async => Result.success(
    items.values.any((p) => p.barcode == barcode && p.id != excludeId),
  );

  @override
  Future<Result<int>> nextAutoSkuNumber() async {
    var max = 0;
    final pattern = RegExp(r'^P-(\d+)$');
    for (final p in items.values) {
      final m = pattern.firstMatch(p.sku);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        if (n > max) {
          max = n;
        }
      }
    }
    return Result.success(max + 1);
  }

  @override
  Future<Result<void>> create(Product product) async {
    items[product.id] = product;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> update(Product product) async {
    items[product.id] = product;
    return const Result.success(null);
  }
}

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository(this.products);

  final FakeProductRepository products;
  final Map<String, Category> items = {};

  /// When set, `search` fails with this failure.
  Failure? searchFailure;

  @override
  Future<Result<List<Category>>> search({
    String query = '',
    bool includeArchived = false,
  }) async {
    if (searchFailure != null) {
      return Result.failure(searchFailure!);
    }
    final q = query.toLowerCase();
    final list =
        items.values
            .where((c) => includeArchived || !c.isArchived)
            .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Result.success(list);
  }

  @override
  Future<Result<Category>> getById(String id) async => items[id] == null
      ? _notFound('Category', id)
      : Result.success(items[id]!);

  @override
  Future<Result<bool>> nameExists(String name, {String? excludeId}) async =>
      Result.success(
        items.values.any(
          (c) =>
              !c.isArchived &&
              c.id != excludeId &&
              c.name.toLowerCase() == name.toLowerCase(),
        ),
      );

  @override
  Future<Result<int>> countProducts(
    String categoryId, {
    required bool activeOnly,
  }) async => Result.success(
    products.items.values
        .where(
          (p) => p.categoryId == categoryId && (!activeOnly || !p.isArchived),
        )
        .length,
  );

  @override
  Future<Result<void>> create(Category category) async {
    items[category.id] = category;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> update(Category category) async {
    items[category.id] = category;
    return const Result.success(null);
  }
}

class FakeUnitRepository implements UnitRepository {
  FakeUnitRepository(this.products);

  final FakeProductRepository products;
  final Map<String, UnitOfMeasure> items = {};

  /// When set, `search` fails with this failure.
  Failure? searchFailure;

  @override
  Future<Result<List<UnitOfMeasure>>> search({
    String query = '',
    bool includeArchived = false,
  }) async {
    if (searchFailure != null) {
      return Result.failure(searchFailure!);
    }
    final q = query.toLowerCase();
    final list =
        items.values
            .where((u) => includeArchived || !u.isArchived)
            .where(
              (u) =>
                  q.isEmpty ||
                  u.name.toLowerCase().contains(q) ||
                  u.symbol.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Result.success(list);
  }

  @override
  Future<Result<UnitOfMeasure>> getById(String id) async =>
      items[id] == null ? _notFound('Unit', id) : Result.success(items[id]!);

  @override
  Future<Result<bool>> symbolExists(String symbol, {String? excludeId}) async =>
      Result.success(
        items.values.any(
          (u) =>
              u.id != excludeId &&
              u.symbol.toLowerCase() == symbol.toLowerCase(),
        ),
      );

  @override
  Future<Result<int>> countProducts(
    String unitId, {
    required bool activeOnly,
  }) async => Result.success(
    products.items.values
        .where((p) => p.unitId == unitId && (!activeOnly || !p.isArchived))
        .length,
  );

  @override
  Future<Result<void>> create(UnitOfMeasure unit) async {
    items[unit.id] = unit;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> update(UnitOfMeasure unit) async {
    items[unit.id] = unit;
    return const Result.success(null);
  }
}

bool _partyMatches(String q, List<String?> fields) =>
    q.isEmpty || fields.any((f) => f != null && f.toLowerCase().contains(q));

class FakeCustomerRepository implements CustomerRepository {
  final Map<String, Customer> items = {};

  /// When set, `search` fails with this failure.
  Failure? searchFailure;

  @override
  Future<Result<List<Customer>>> search({
    String query = '',
    bool includeArchived = false,
  }) async {
    if (searchFailure != null) {
      return Result.failure(searchFailure!);
    }
    final q = query.toLowerCase();
    final list =
        items.values
            .where((c) => includeArchived || !c.isArchived)
            .where((c) => _partyMatches(q, [c.name, c.phone, c.email]))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Result.success(list);
  }

  @override
  Future<Result<Customer>> getById(String id) async => items[id] == null
      ? _notFound('Customer', id)
      : Result.success(items[id]!);

  @override
  Future<Result<void>> create(Customer customer) async {
    items[customer.id] = customer;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> update(Customer customer) async {
    items[customer.id] = customer;
    return const Result.success(null);
  }
}

class FakeSupplierRepository implements SupplierRepository {
  final Map<String, Supplier> items = {};

  /// When set, `search` fails with this failure.
  Failure? searchFailure;

  @override
  Future<Result<List<Supplier>>> search({
    String query = '',
    bool includeArchived = false,
  }) async {
    if (searchFailure != null) {
      return Result.failure(searchFailure!);
    }
    final q = query.toLowerCase();
    final list =
        items.values
            .where((c) => includeArchived || !c.isArchived)
            .where((c) => _partyMatches(q, [c.name, c.phone, c.email]))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return Result.success(list);
  }

  @override
  Future<Result<Supplier>> getById(String id) async => items[id] == null
      ? _notFound('Supplier', id)
      : Result.success(items[id]!);

  @override
  Future<Result<void>> create(Supplier supplier) async {
    items[supplier.id] = supplier;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> update(Supplier supplier) async {
    items[supplier.id] = supplier;
    return const Result.success(null);
  }
}

/// Image storage that records stored sources and fails on request.
class FakeImageStorage implements ImageStorage {
  final List<String> stored = [];
  Failure? failure;

  @override
  Future<Result<String>> storeProductImage(String sourcePath) async {
    if (failure != null) {
      return Result.failure(failure!);
    }
    stored.add(sourcePath);
    return Result.success('product_images/img_${stored.length}.jpg');
  }

  @override
  Future<String> resolvePath(String relativePath) async =>
      '/tmp/fake/$relativePath';
}
