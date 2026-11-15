/// Base class for violations of domain invariants (programming or input
/// errors detected by value objects and domain services).
class DomainException implements Exception {
  /// Creates a [DomainException] with a developer/user readable [message].
  const DomainException(this.message);

  /// Description of the violated rule.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when two monetary values with different currencies (or decimal
/// places) are combined.
class CurrencyMismatchException extends DomainException {
  /// Creates a [CurrencyMismatchException].
  const CurrencyMismatchException(super.message);
}

/// Thrown when integer arithmetic would exceed the 64-bit range.
class ArithmeticOverflowException extends DomainException {
  /// Creates an [ArithmeticOverflowException].
  const ArithmeticOverflowException([
    super.message = 'Arithmetic overflow: value is too large.',
  ]);
}
