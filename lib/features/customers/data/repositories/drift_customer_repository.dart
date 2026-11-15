import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/customers/data/mappers/customer_mapper.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Drift implementation of [CustomerRepository].
final class DriftCustomerRepository implements CustomerRepository {
  /// Creates the repository.
  const DriftCustomerRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  @override
  Future<Result<List<Customer>>> search({
    String query = '',
    bool includeArchived = false,
  }) => guardDatabase(() async {
    final currency = await _currency();
    final text = query.trim();
    final select = _db.select(_db.customers)
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
        .map((row) => customerFromRow(row, currency))
        .toList();
  });

  @override
  Future<Result<Customer>> getById(String id) => guardDatabase(() async {
    final currency = await _currency();
    final row = await (_db.select(
      _db.customers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Customer not found.'));
    }
    return customerFromRow(row, currency);
  });

  @override
  Future<Result<void>> create(Customer customer) => guardDatabase(
    () => _db.into(_db.customers).insert(customerToCompanion(customer)),
  );

  @override
  Future<Result<void>> update(Customer customer) => guardDatabase(() async {
    final affected =
        await (_db.update(_db.customers)
              ..where((t) => t.id.equals(customer.id)))
            .write(customerToCompanion(customer));
    if (affected == 0) {
      throw const FailureException(NotFoundFailure('Customer not found.'));
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
