import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/product_classification/domain/repositories/product_classification_repository.dart';
import 'package:inventrix/features/product_classification/domain/services/classification_audit.dart';
import 'package:inventrix/features/product_classification/domain/services/classification_validator.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Shared by the use cases: runs [change] and its audit entry in one
/// database transaction when auditing is configured.
Future<Result<T>> _audited<T>({
  required TransactionRunner? transactions,
  required AuditLogRepository? audit,
  required Future<Result<void>> Function() change,
  required Future<Result<void>> Function(AuditLogRepository audit) record,
  required T value,
}) async {
  if (transactions == null || audit == null) {
    final done = await change();
    return done.isFailure ? Result.failure(done.failureOrNull!) : Result.success(value);
  }
  return transactions.runResult(() async {
    (await change()).getOrThrow();
    (await record(audit)).getOrThrow();
    return value;
  });
}

/// Adds a classification to a product.
final class AddProductClassification {
  /// Creates the use case.
  const AddProductClassification({
    required ProductClassificationRepository repository,
    required IdGenerator ids,
    required Clock clock,
    AuditLogRepository? audit,
    TransactionRunner? transactions,
  }) : _repository = repository,
       _ids = ids,
       _clock = clock,
       _audit = audit,
       _transactions = transactions;

  final ProductClassificationRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;
  final AuditLogRepository? _audit;
  final TransactionRunner? _transactions;

  /// Validates the entered values and stores them.
  Future<Result<ProductClassification>> call({
    required String productId,
    required String system,
    required String code,
    required ClassificationType type,
    String description = '',
    String country = '',
    bool makePrimary = false,
  }) async {
    final now = _clock.now();
    final built = ClassificationValidator.build(
      id: _ids.newId(),
      productId: productId,
      systemText: system,
      codeText: code,
      type: type,
      isPrimary: makePrimary,
      now: now,
      descriptionText: description,
      countryText: country,
    );
    final classification = built.valueOrNull;
    if (classification == null) {
      return Result.failure(built.failureOrNull!);
    }
    return _audited(
      transactions: _transactions,
      audit: _audit,
      change: () => _repository.add(classification),
      record: (audit) => audit.record(
        ClassificationAudit.entry(
          id: _ids.newId(),
          action: 'added',
          classification: classification,
          at: now,
        ),
      ),
      value: classification,
    );
  }
}

/// Edits an existing classification.
final class UpdateProductClassification {
  /// Creates the use case.
  const UpdateProductClassification({
    required ProductClassificationRepository repository,
    required Clock clock,
    IdGenerator? ids,
    AuditLogRepository? audit,
    TransactionRunner? transactions,
  }) : _repository = repository,
       _clock = clock,
       _ids = ids,
       _audit = audit,
       _transactions = transactions;

  final ProductClassificationRepository _repository;
  final Clock _clock;
  final IdGenerator? _ids;
  final AuditLogRepository? _audit;
  final TransactionRunner? _transactions;

  /// Re-validates [existing] with the new values and stores it.
  Future<Result<void>> call({
    required ProductClassification existing,
    required String system,
    required String code,
    required ClassificationType type,
    String description = '',
    String country = '',
  }) async {
    final now = _clock.now();
    final built = ClassificationValidator.build(
      id: existing.id,
      productId: existing.productId,
      systemText: system,
      codeText: code,
      type: type,
      isPrimary: existing.isPrimary,
      now: now,
      descriptionText: description,
      countryText: country,
      createdAt: existing.createdAt,
    );
    final classification = built.valueOrNull;
    if (classification == null) {
      return Result.failure(built.failureOrNull!);
    }
    final ids = _ids;
    return _audited<void>(
      transactions: ids == null ? null : _transactions,
      audit: _audit,
      change: () => _repository.update(classification),
      record: (audit) => audit.record(
        ClassificationAudit.entry(
          id: ids!.newId(),
          action: 'updated',
          classification: classification,
          before: existing,
          at: now,
        ),
      ),
      value: null,
    );
  }
}

/// Removes a classification. Posted documents keep their own snapshot.
final class RemoveProductClassification {
  /// Creates the use case.
  const RemoveProductClassification(
    this._repository, {
    Clock? clock,
    IdGenerator? ids,
    AuditLogRepository? audit,
    TransactionRunner? transactions,
  }) : _clock = clock,
       _ids = ids,
       _audit = audit,
       _transactions = transactions;

  final ProductClassificationRepository _repository;
  final Clock? _clock;
  final IdGenerator? _ids;
  final AuditLogRepository? _audit;
  final TransactionRunner? _transactions;

  /// Removes classification [id].
  Future<Result<void>> call(String id) async {
    final clock = _clock;
    final ids = _ids;
    if (clock == null || ids == null || _audit == null || _transactions == null) {
      return _repository.remove(id);
    }
    final loaded = await _repository.getById(id);
    if (loaded.isFailure) {
      return Result.failure(loaded.failureOrNull!);
    }
    final existing = loaded.valueOrNull;
    if (existing == null) {
      return const Result.success(null);
    }
    return _audited<void>(
      transactions: _transactions,
      audit: _audit,
      change: () => _repository.remove(id),
      record: (audit) => audit.record(
        ClassificationAudit.entry(
          id: ids.newId(),
          action: 'removed',
          classification: existing,
          before: existing,
          at: clock.now(),
        ),
      ),
      value: null,
    );
  }
}

/// Chooses which classification is printed on documents.
final class SetPrimaryProductClassification {
  /// Creates the use case.
  const SetPrimaryProductClassification(
    this._repository, {
    Clock? clock,
    IdGenerator? ids,
    AuditLogRepository? audit,
    TransactionRunner? transactions,
  }) : _clock = clock,
       _ids = ids,
       _audit = audit,
       _transactions = transactions;

  final ProductClassificationRepository _repository;
  final Clock? _clock;
  final IdGenerator? _ids;
  final AuditLogRepository? _audit;
  final TransactionRunner? _transactions;

  /// Makes [id] the primary classification of [productId].
  Future<Result<void>> call(String productId, String id) async {
    final clock = _clock;
    final ids = _ids;
    if (clock == null || ids == null || _audit == null || _transactions == null) {
      return _repository.setPrimary(productId, id);
    }
    final loaded = await _repository.getById(id);
    final existing = loaded.valueOrNull;
    if (existing == null) {
      return loaded.isFailure
          ? Result.failure(loaded.failureOrNull!)
          : _repository.setPrimary(productId, id);
    }
    return _audited<void>(
      transactions: _transactions,
      audit: _audit,
      change: () => _repository.setPrimary(productId, id),
      record: (audit) => audit.record(
        ClassificationAudit.entry(
          id: ids.newId(),
          action: 'primary_changed',
          classification: existing.withPrimary(isPrimary: true),
          before: existing,
          at: clock.now(),
        ),
      ),
      value: null,
    );
  }
}
