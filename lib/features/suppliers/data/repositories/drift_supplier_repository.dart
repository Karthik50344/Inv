import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/suppliers/data/mappers/supplier_mapper.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Drift implementation of [SupplierRepository].
final class DriftSupplierRepository implements SupplierRepository {
  /// Creates the repository.
  const DriftSupplierRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  @override
  Future<Result<List<Supplier>>> search({
    String query = '',
    bool includeArchived = false,
  }) => guardDatabase(() async {
    final currency = await _currency();
    final text = query.trim();
    final select = _db.select(_db.suppliers)
      ..where((t) {
        Expression<bool> predicate = const Constant(true);
        if (!includeArchived) {
          predicate = predicate & t.archivedAt.isNull();
        }
        if (text.isNotEmpty) {
          predicate =
              predicate &
              (t.name.contains(text) |
                  t.phone.contains(text) |
                  t.email.contains(text));
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return (await select.get())
        .map((row) => supplierFromRow(row, currency))
        .toList();
  });

  @override
  Future<Result<Supplier>> getById(String id) => guardDatabase(() async {
    final currency = await _currency();
    final row = await (_db.select(
      _db.suppliers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Supplier not found.'));
    }
    return supplierFromRow(row, currency);
  });

  @override
  Future<Result<void>> create(Supplier supplier) => guardDatabase(
    () => _db.into(_db.suppliers).insert(supplierToCompanion(supplier)),
  );

  @override
  Future<Result<void>> update(Supplier supplier) => guardDatabase(() async {
    final affected =
        await (_db.update(_db.suppliers)
              ..where((t) => t.id.equals(supplier.id)))
            .write(supplierToCompanion(supplier));
    if (affected == 0) {
      throw const FailureException(NotFoundFailure('Supplier not found.'));
    }
  });

  Future<CurrencyConfig> _currency() async {
    final result = await _settings.getCurrencyConfig();
    final config = result.valueOrNull;
    if (config == null) {
      throw FailureException(result.failureOrNull!);
    }
    return config;
  }
}
