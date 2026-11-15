import 'package:inventrix/core/errors/failure.dart';

/// Outcome of an operation: either a [Success] with a value or an [Err]
/// carrying a [Failure].
sealed class Result<T> {
  const Result();

  /// Creates a successful result.
  const factory Result.success(T value) = Success<T>;

  /// Creates a failed result.
  const factory Result.failure(Failure failure) = Err<T>;

  /// Whether this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Whether this is an [Err].
  bool get isFailure => this is Err<T>;

  /// The value if successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure if failed, otherwise `null`.
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Err<T>(failure: final f) => f,
  };

  /// Folds the result into a single value.
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) => switch (this) {
    Success<T>(:final value) => success(value),
    Err<T>(failure: final f) => failure(f),
  };

  /// Returns the value, or throws a [FailureException] carrying the failure.
  ///
  /// Use inside `TransactionRunner.runResult` so that a failed step rolls the
  /// whole transaction back while keeping the original [Failure] type.
  T getOrThrow() => switch (this) {
    Success<T>(:final value) => value,
    Err<T>(failure: final f) => throw FailureException(f),
  };

  /// Transforms a successful value; failures pass through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Result<R>.success(transform(value)),
    Err<T>(failure: final f) => Result<R>.failure(f),
  };

  /// Chains another fallible step; failures pass through unchanged.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Success<T>(:final value) => transform(value),
    Err<T>(failure: final f) => Result<R>.failure(f),
  };
}

/// Successful [Result].
final class Success<T> extends Result<T> {
  /// Creates a [Success] holding [value].
  const Success(this.value);

  /// The produced value.
  final T value;

  @override
  bool operator ==(Object other) => other is Success<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Success, value);

  @override
  String toString() => 'Success($value)';
}

/// Failed [Result].
final class Err<T> extends Result<T> {
  /// Creates an [Err] holding [failure].
  const Err(this.failure);

  /// The reason for failure.
  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
