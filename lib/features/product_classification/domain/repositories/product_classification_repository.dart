import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';

/// Storage of product classifications. A product that has any
/// classification always has exactly one primary.
abstract interface class ProductClassificationRepository {
  /// All classifications of [productId], primary first.
  Future<Result<List<ProductClassification>>> listForProduct(String productId);

  /// The classification with [id], or `null`.
  Future<Result<ProductClassification?>> getById(String id);

  /// The primary classification of [productId], or `null`.
  Future<Result<ProductClassification?>> primaryFor(String productId);

  /// Adds [classification]. The product's first one becomes primary; a new
  /// primary replaces the old one. A repeated system + code on the same
  /// product fails with a `DuplicateEntryFailure`.
  Future<Result<void>> add(ProductClassification classification);

  /// Changes code, description, country and type. The primary flag is kept;
  /// use [setPrimary] to move it.
  Future<Result<void>> update(ProductClassification classification);

  /// Removes a classification. Posted documents keep their own snapshot, so
  /// removal never changes them. If it was primary, the oldest remaining one
  /// becomes primary.
  Future<Result<void>> remove(String id);

  /// Makes [id] the primary classification of [productId].
  Future<Result<void>> setPrimary(String productId, String id);

  /// Codes already used on products that match [query] (code, description
  /// or system), most used first. Works fully offline.
  Future<Result<List<ClassificationSuggestion>>> search(
    String query, {
    int limit = 20,
  });
}
