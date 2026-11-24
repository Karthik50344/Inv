import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/services/product_audit.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Chooses a product's tax category and optional explicit override.
///
/// The product stores only references, never a tax amount. The category and
/// the override must exist and be active. The change and its audit event
/// (with before and after, flagged as a tax change) commit together.
final class SetProductTaxTreatment {
  /// Creates the use case.
  const SetProductTaxTreatment({
    required ProductRepository products,
    required TaxRepository tax,
    required TransactionRunner transactions,
    required AuditLogRepository audit,
    required Clock clock,
    required IdGenerator ids,
  }) : _products = products,
       _tax = tax,
       _transactions = transactions,
       _audit = audit,
       _clock = clock,
       _ids = ids;

  final ProductRepository _products;
  final TaxRepository _tax;
  final TransactionRunner _transactions;
  final AuditLogRepository _audit;
  final Clock _clock;
  final IdGenerator _ids;

  /// Sets the category (`null` = inherit from the tax profile) and the
  /// override (`null` = none) of product [productId].
  Future<Result<void>> call(
    String productId, {
    String? taxCategoryId,
    String? taxOverrideId,
  }) async {
    final loaded = await _products.getById(productId);
    final product = loaded.valueOrNull;
    if (product == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final config = await _tax.loadConfiguration();
    final configuration = config.valueOrNull;
    if (configuration == null) {
      return Result.failure(config.failureOrNull!);
    }
    final errors = <String, String>{};
    if (taxCategoryId != null) {
      final category = configuration.category(taxCategoryId);
      if (category == null || !category.isActive) {
        errors['taxCategoryId'] = 'Choose an active tax category.';
      }
    }
    if (taxOverrideId != null) {
      final override = configuration.override(taxOverrideId);
      if (override == null || !override.isActive) {
        errors['taxOverrideId'] = 'Choose an active tax override.';
      }
    }
    if (errors.isNotEmpty) {
      return Result.failure(
        ValidationFailure('Please correct the highlighted fields.', fieldErrors: errors),
      );
    }
    if (product.taxCategoryId == taxCategoryId && product.taxOverrideId == taxOverrideId) {
      return const Result.success(null);
    }
    final now = _clock.now();
    final changed = product.withTaxTreatment(
      at: now,
      taxCategoryId: taxCategoryId,
      taxOverrideId: taxOverrideId,
    );
    final entry = ProductAudit.updated(product, changed, id: _ids.newId());
    return _transactions.runResult<void>(() async {
      (await _products.update(changed)).getOrThrow();
      if (entry != null) {
        (await _audit.record(entry)).getOrThrow();
      }
    });
  }
}
