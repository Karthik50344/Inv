import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/transaction_runner.dart';

/// [TransactionRunner] backed by Drift's `transaction`.
///
/// Drift propagates the active transaction through the current zone, so DAOs
/// and repositories called inside [run] automatically share it. Nested calls
/// use savepoints.
final class DriftTransactionRunner implements TransactionRunner {
  /// Creates a runner for [database].
  const DriftTransactionRunner(this._database);

  final AppDatabase _database;

  @override
  Future<T> run<T>(Future<T> Function() action) =>
      _database.transaction(action);

  @override
  Future<Result<T>> runResult<T>(Future<T> Function() action) =>
      guardDatabase(() => _database.transaction(action));
}
