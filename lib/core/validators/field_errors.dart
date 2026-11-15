import 'package:inventrix/core/errors/failure.dart';

/// Collects per-field validation messages (first message per field wins).
final class FieldErrors {
  final Map<String, String> _errors = {};

  /// Records [message] for [field] when it is non-null.
  void add(String field, String? message) {
    if (message != null) {
      _errors.putIfAbsent(field, () => message);
    }
  }

  /// Whether no errors were recorded.
  bool get isEmpty => _errors.isEmpty;

  /// Converts the collected errors into a [ValidationFailure].
  ValidationFailure toFailure() => ValidationFailure(
    'Please correct the highlighted fields.',
    fieldErrors: Map.unmodifiable(_errors),
  );
}
