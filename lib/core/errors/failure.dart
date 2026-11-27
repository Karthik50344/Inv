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

/// A backup needs a recovery passphrase (or the one given was wrong).
final class BackupPassphraseFailure extends Failure {
  /// Creates a [BackupPassphraseFailure]; [incorrect] is `true` when a
  /// passphrase was supplied but did not match.
  const BackupPassphraseFailure(
    super.message, {
    this.incorrect = false,
    super.cause,
    super.stackTrace,
  });

  /// Whether a supplied passphrase was wrong.
  final bool incorrect;
}

/// Restoring a backup failed.
final class RestoreFailure extends Failure {
  /// Creates a [RestoreFailure].
  const RestoreFailure(super.message, {super.cause, super.stackTrace});
}

/// The tax configuration cannot answer a calculation: no applicable rule, an
/// unknown category or profile, or a rule whose components are unusable.
///
/// A missing rule is never treated as 0% tax; callers must surface this.
final class TaxConfigurationFailure extends Failure {
  /// Creates a [TaxConfigurationFailure].
  const TaxConfigurationFailure(super.message, {super.cause, super.stackTrace});
}

/// Several equally applicable tax rules disagree; no rule is picked
/// arbitrarily.
final class TaxRuleConflictFailure extends Failure {
  /// Creates a [TaxRuleConflictFailure] naming the conflicting [ruleIds].
  const TaxRuleConflictFailure(
    super.message, {
    required this.ruleIds,
    super.cause,
    super.stackTrace,
  });

  /// Identifiers of the rules that tie.
  final List<String> ruleIds;
}

/// The audit subsystem could not record or verify an event. A business
/// operation that cannot be audited is not committed.
final class AuditFailure extends Failure {
  /// Creates an [AuditFailure].
  const AuditFailure(super.message, {super.cause, super.stackTrace});
}

/// An auditor export could not be created or verified.
final class ExportFailure extends Failure {
  /// Creates an [ExportFailure].
  const ExportFailure(super.message, {super.cause, super.stackTrace});
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
