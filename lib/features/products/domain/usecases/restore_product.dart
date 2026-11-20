import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/products/domain/services/product_audit.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';

/// Restores an archived product.
final class RestoreProduct {
  /// Creates the use case.
  const RestoreProduct({
    required ProductRepository products,
    required Clock clock,
    AuditLogRepository? audit,
    TransactionRunner? transactions,
    IdGenerator? ids,
  }) : _products = products,
       _clock = clock,
       _audit = audit,
       _transactions = transactions,
       _ids = ids;

  final ProductRepository _products;
  final Clock _clock;
  final AuditLogRepository? _audit;
  final TransactionRunner? _transactions;
  final IdGenerator? _ids;

  /// Restores product [id]. Restoring an active product succeeds.
  Future<Result<void>> call(String id) async {
    final loaded = await _products.getById(id);
    final product = loaded.valueOrNull;
    if (product == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (!product.isArchived) {
      return const Result.success(null);
    }
    final at = _clock.now();
    final changed = product.restored(at);
    final audit = _audit;
    final transactions = _transactions;
    final ids = _ids;
    if (audit == null || transactions == null || ids == null) {
      return _products.update(changed);
    }
    return transactions.runResult<void>(() async {
      (await _products.update(changed)).getOrThrow();
      (await audit.record(
        ProductAudit.archivedChanged(
          changed,
          id: ids.newId(),
          archived: false,
          at: at,
        ),
      )).getOrThrow();
    });
  }
}
