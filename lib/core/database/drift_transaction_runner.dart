import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/audit_correlation.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';

/// [TransactionRunner] backed by Drift's `transaction`.
///
/// Drift propagates the active transaction through the current zone, so DAOs
/// and repositories called inside [run] automatically share it. Nested calls
/// use savepoints.
final class DriftTransactionRunner implements TransactionRunner {
  /// Creates a runner for [database].
  const DriftTransactionRunner(this._database, {IdGenerator? ids})
    : _ids = ids;

  final AppDatabase _database;
  final IdGenerator? _ids;

  T _scoped<T>(T Function() body) {
    final ids = _ids;
    return ids == null ? body() : AuditCorrelation.run(ids.newId(), body);
  }

  @override
  Future<T> run<T>(Future<T> Function() action) =>
      _scoped(() => _database.transaction(action));

  @override
  Future<Result<T>> runResult<T>(Future<T> Function() action) =>
      _scoped(() => guardDatabase(() => _database.transaction(action)));
}
