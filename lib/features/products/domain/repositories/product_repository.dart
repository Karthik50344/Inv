import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';

/// Persistence contract for products.
abstract interface class ProductRepository {
  /// Lists products ordered by name matching [filter].
  Future<Result<List<Product>>> search(ProductFilter filter);

  /// Loads one product; fails with `NotFoundFailure` if missing.
  Future<Result<Product>> getById(String id);

  /// Whether [sku] is used by any product (archived included), ignoring
  /// [excludeId]. [sku] must already be normalized.
  Future<Result<bool>> skuExists(String sku, {String? excludeId});

  /// Whether [barcode] is used by any product, ignoring [excludeId].
  Future<Result<bool>> barcodeExists(String barcode, {String? excludeId});

  /// Next number for auto-generated SKUs of the form `P-000001`.
  Future<Result<int>> nextAutoSkuNumber();

  /// Inserts a product (and its zero inventory balance) atomically.
  Future<Result<void>> create(Product product);

  /// Replaces an existing product (also used for archive/restore).
  Future<Result<void>> update(Product product);
}
