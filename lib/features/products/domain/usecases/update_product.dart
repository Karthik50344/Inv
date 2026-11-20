import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/products/domain/services/product_audit.dart';
import 'package:inventrix/features/products/domain/services/product_validator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

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
    AuditLogRepository? audit,
    TransactionRunner? transactions,
    IdGenerator? ids,
  }) : _validator = validator,
       _products = products,
       _clock = clock,
       _audit = audit,
       _transactions = transactions,
       _ids = ids;

  final ProductValidator _validator;
  final ProductRepository _products;
  final Clock _clock;
  final AuditLogRepository? _audit;
  final TransactionRunner? _transactions;
  final IdGenerator? _ids;

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
    final audit = _audit;
    final transactions = _transactions;
    final ids = _ids;
    if (audit == null || transactions == null || ids == null) {
      final saved = await _products.update(product);
      return saved.isFailure
          ? Result.failure(saved.failureOrNull!)
          : Result.success(product);
    }
    return transactions.runResult(() async {
      (await _products.update(product)).getOrThrow();
      final entry = ProductAudit.updated(existing, product, id: ids.newId());
      if (entry != null) {
        (await audit.record(entry)).getOrThrow();
      }
      return product;
    });
  }
}
