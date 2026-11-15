import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/services/product_validator.dart';

/// Validates and updates an existing product.
///
/// Historical documents keep their own snapshots, so editing master data
/// never alters past invoices.
final class UpdateProduct {
  /// Creates the use case.
  const UpdateProduct({
    required ProductValidator validator,
    required ProductRepository products,
    required Clock clock,
  }) : _validator = validator,
       _products = products,
       _clock = clock;

  final ProductValidator _validator;
  final ProductRepository _products;
  final Clock _clock;

  /// Updates product [id] from [draft].
  Future<Result<Product>> call(String id, ProductDraft draft) async {
    final loaded = await _products.getById(id);
    final existing = loaded.valueOrNull;
    if (existing == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final validated = await _validator.validate(draft, existing: existing);
    final fields = validated.valueOrNull;
    if (fields == null) {
      return Result.failure(validated.failureOrNull!);
    }
    final product = Product.fromFields(
      id: existing.id,
      sku: fields.sku!,
      fields: fields,
      createdAt: existing.createdAt,
      updatedAt: _clock.now(),
      archivedAt: existing.archivedAt,
    );
    final saved = await _products.update(product);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(product);
  }
}
