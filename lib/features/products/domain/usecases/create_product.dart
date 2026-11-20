import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/services/product_audit.dart';
import 'package:inventrix/features/products/domain/services/product_validator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Validates and creates a product, generating a SKU when left blank.
final class CreateProduct {
  /// Creates the use case.
  const CreateProduct({
    required ProductValidator validator,
    required ProductRepository products,
    required IdGenerator ids,
    required Clock clock,
    AuditLogRepository? audit,
    TransactionRunner? transactions,
  }) : _validator = validator,
       _products = products,
       _ids = ids,
       _clock = clock,
       _audit = audit,
       _transactions = transactions;

  final ProductValidator _validator;
  final ProductRepository _products;
  final IdGenerator _ids;
  final Clock _clock;
  final AuditLogRepository? _audit;
  final TransactionRunner? _transactions;

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
    final audit = _audit;
    final transactions = _transactions;
    if (audit == null || transactions == null) {
      final saved = await _products.create(product);
      return saved.isFailure
          ? Result.failure(saved.failureOrNull!)
          : Result.success(product);
    }
    // The product and its audit event commit together or not at all.
    return transactions.runResult(() async {
      (await _products.create(product)).getOrThrow();
      (await audit.record(
        ProductAudit.created(product, id: _ids.newId()),
      )).getOrThrow();
      return product;
    });
  }
}
