/// Base type for all expected, recoverable errors surfaced by use cases and
/// repositories. Infrastructure exceptions are translated into a [Failure].
sealed class Failure {
  /// Creates a failure with a diagnostic [message].
  const Failure(this.message, {this.cause, this.stackTrace});

  /// Diagnostic message (safe for logs, not necessarily for end users).
  final String message;

  /// The underlying exception, if any. Never shown to users.
  final Object? cause;

  /// Stack trace captured when the failure was created, if any.
  final StackTrace? stackTrace;

  /// Message that can be shown to a normal user. Never contains SQL or
  /// stack traces.
  String get userMessage => message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Input or business-rule validation failed.
final class ValidationFailure extends Failure {
  /// Creates a [ValidationFailure], optionally with per-field messages.
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  /// Messages keyed by field name.
  final Map<String, String> fieldErrors;
}

/// A database operation failed.
final class DatabaseFailure extends Failure {
  /// Creates a [DatabaseFailure].
  const DatabaseFailure(super.message, {super.cause, super.stackTrace});
}

/// A requested record does not exist.
final class NotFoundFailure extends Failure {
  /// Creates a [NotFoundFailure].
  const NotFoundFailure(super.message, {super.cause, super.stackTrace});
}

/// A stock-out would drive inventory below zero.
final class InsufficientStockFailure extends Failure {
  /// Creates an [InsufficientStockFailure].
  const InsufficientStockFailure(
    super.message, {
    required this.productId,
    required this.requestedMilli,
    required this.availableMilli,
    super.cause,
    super.stackTrace,
  });

  /// The product that lacks stock.
  final String productId;

  /// Requested quantity in milli-units.
  final int requestedMilli;

  /// Available quantity in milli-units.
  final int availableMilli;
}

/// A unique constraint (SKU, barcode, document number, ...) was violated.
final class DuplicateEntryFailure extends Failure {
  /// Creates a [DuplicateEntryFailure].
  const DuplicateEntryFailure(super.message, {super.cause, super.stackTrace});
}

/// Creating a backup failed.
final class BackupFailure extends Failure {
  /// Creates a [BackupFailure].
  const BackupFailure(super.message, {super.cause, super.stackTrace});
}

/// Restoring a backup failed.
final class RestoreFailure extends Failure {
  /// Creates a [RestoreFailure].
  const RestoreFailure(super.message, {super.cause, super.stackTrace});
}

/// Anything that was not anticipated.
final class UnexpectedFailure extends Failure {
  /// Creates an [UnexpectedFailure].
  const UnexpectedFailure(super.message, {super.cause, super.stackTrace});

  @override
  String get userMessage => 'Something went wrong. Please try again.';
}

/// Carries a [Failure] across a transaction boundary.
///
/// Throwing this inside `TransactionRunner.run` rolls the transaction back;
/// the repository/use-case guard then converts it back into a failed
/// `Result` without losing the original [Failure] type.
class FailureException implements Exception {
  /// Wraps [failure] so it can be thrown.
  const FailureException(this.failure);

  /// The wrapped failure.
  final Failure failure;

  @override
  String toString() => 'FailureException(${failure.runtimeType})';
}
