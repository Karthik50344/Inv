import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';

/// Archives a product (history is kept; the product leaves active lists).
final class ArchiveProduct {
  /// Creates the use case.
  const ArchiveProduct({
    required ProductRepository products,
    required Clock clock,
  }) : _products = products,
       _clock = clock;

  final ProductRepository _products;
  final Clock _clock;

  /// Archives product [id]. Archiving an archived product succeeds.
  Future<Result<void>> call(String id) async {
    final loaded = await _products.getById(id);
    final product = loaded.valueOrNull;
    if (product == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (product.isArchived) {
      return const Result.success(null);
    }
    return _products.update(product.archived(_clock.now()));
  }
}
