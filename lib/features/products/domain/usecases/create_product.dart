import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/services/product_validator.dart';

/// Validates and creates a product, generating a SKU when left blank.
final class CreateProduct {
  /// Creates the use case.
  const CreateProduct({
    required ProductValidator validator,
    required ProductRepository products,
    required IdGenerator ids,
    required Clock clock,
  }) : _validator = validator,
       _products = products,
       _ids = ids,
       _clock = clock;

  final ProductValidator _validator;
  final ProductRepository _products;
  final IdGenerator _ids;
  final Clock _clock;

  /// Creates a product from [draft].
  Future<Result<Product>> call(ProductDraft draft) async {
    final validated = await _validator.validate(draft, allowBlankSku: true);
    final fields = validated.valueOrNull;
    if (fields == null) {
      return Result.failure(validated.failureOrNull!);
    }
    var sku = fields.sku;
    if (sku == null) {
      final next = await _products.nextAutoSkuNumber();
      final number = next.valueOrNull;
      if (number == null) {
        return Result.failure(next.failureOrNull!);
      }
      sku = 'P-${number.toString().padLeft(6, '0')}';
    }
    final now = _clock.now();
    final product = Product.fromFields(
      id: _ids.newId(),
      sku: sku,
      fields: fields,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _products.create(product);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(product);
  }
}
