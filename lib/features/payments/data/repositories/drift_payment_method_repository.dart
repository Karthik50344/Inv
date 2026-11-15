import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/data/mappers/payment_mapper.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';

/// Drift implementation of [PaymentMethodRepository].
final class DriftPaymentMethodRepository implements PaymentMethodRepository {
  /// Creates the repository.
  const DriftPaymentMethodRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<PaymentMethod>>> list({bool includeArchived = false}) =>
      guardDatabase(() async {
        final query = _db.select(_db.paymentMethods)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]);
        if (!includeArchived) {
          query.where((t) => t.archivedAt.isNull());
        }
        return (await query.get()).map(methodFromRow).toList();
      });

  @override
  Future<Result<PaymentMethod>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.paymentMethods,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(
        NotFoundFailure('Payment method not found.'),
      );
    }
    return methodFromRow(row);
  });

  @override
  Future<Result<void>> create(PaymentMethod method) => guardDatabase(
    () => _db.into(_db.paymentMethods).insert(methodToCompanion(method)),
  );

  @override
  Future<Result<void>> update(PaymentMethod method) => guardDatabase(
    () => (_db.update(
      _db.paymentMethods,
    )..where((t) => t.id.equals(method.id))).write(methodToCompanion(method)),
  );
}
