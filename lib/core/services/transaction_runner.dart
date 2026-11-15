import 'package:inventrix/core/result/result.dart';

/// Runs a unit of work atomically.
///
/// Use cases that change several related records (posting an invoice, a
/// stock adjustment, a payment with allocations, ...) call [runResult] once
/// and perform all reads/writes inside it. If the action throws, every change
/// made inside it is rolled back.
abstract interface class TransactionRunner {
  /// Executes [action] inside a database transaction and rethrows errors.
  Future<T> run<T>(Future<T> Function() action);

  /// Executes [action] inside a transaction and converts any error into a
  /// failed [Result].
  ///
  /// Inside [action], unwrap repository results with `Result.getOrThrow()`:
  /// a failed step then aborts and rolls back the transaction, and the
  /// original `Failure` is returned to the caller.
  Future<Result<T>> runResult<T>(Future<T> Function() action);
}
