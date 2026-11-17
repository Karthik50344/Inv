import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/data/mappers/tax_rate_mapper.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';

/// Drift implementation of [TaxRateRepository].
final class DriftTaxRateRepository implements TaxRateRepository {
  /// Creates the repository.
  const DriftTaxRateRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<TaxRate>>> list({bool includeArchived = false}) =>
      guardDatabase(() async {
        final query = _db.select(_db.taxRates)
          ..where(
            (t) =>
                includeArchived ? const Constant(true) : t.archivedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]);
        return (await query.get()).map(taxRateFromRow).toList();
      });

  @override
  Future<Result<TaxRate>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.taxRates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Tax rate not found.'));
    }
    return taxRateFromRow(row);
  });

  @override
  Future<Result<bool>> nameExists(String name, {String? excludingId}) =>
      guardDatabase(() async {
        final count = _db.taxRates.id.count();
        final query = _db.selectOnly(_db.taxRates)
          ..addColumns([count])
          ..where(
            _db.taxRates.archivedAt.isNull() &
                _db.taxRates.name.lower().equalsExp(
                  Variable<String>(name).lower(),
                ) &
                (excludingId == null
                    ? const Constant(true)
                    : _db.taxRates.id.equals(excludingId).not()),
          );
        final row = await query.getSingle();
        return (row.read(count) ?? 0) > 0;
      });

  @override
  Future<Result<bool>> isInUse(String id) => guardDatabase(() async {
    final row = await _db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM products WHERE tax_rate_id = ?) + '
          '(SELECT COUNT(*) FROM expenses WHERE tax_rate_id = ?) AS uses',
          variables: [Variable.withString(id), Variable.withString(id)],
          readsFrom: {_db.products, _db.expenses},
        )
        .getSingle();
    return row.read<int>('uses') > 0;
  });

  @override
  Future<Result<void>> create(TaxRate taxRate) => guardDatabase(
    () => _db.into(_db.taxRates).insert(taxRateToCompanion(taxRate)),
  );

  @override
  Future<Result<void>> update(TaxRate taxRate) => guardDatabase(() async {
    final changed =
        await (_db.update(_db.taxRates)..where((t) => t.id.equals(taxRate.id)))
            .write(taxRateToCompanion(taxRate));
    if (changed == 0) {
      throw const FailureException(NotFoundFailure('Tax rate not found.'));
    }
  });
}
