import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';

/// Persistence contract for payment methods.
abstract interface class PaymentMethodRepository {
  /// Methods ordered by name; archived ones only if [includeArchived].
  Future<Result<List<PaymentMethod>>> list({bool includeArchived = false});

  /// Loads one method; `NotFoundFailure` if missing.
  Future<Result<PaymentMethod>> getById(String id);

  /// Inserts a method; `DuplicateEntryFailure` if an active method has the
  /// same name.
  Future<Result<void>> create(PaymentMethod method);

  /// Replaces a method (used to archive and restore).
  Future<Result<void>> update(PaymentMethod method);
}
