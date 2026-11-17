import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/numbering_settings.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';

/// Persistence contract for document numbering settings and counters.
abstract interface class NumberingRepository {
  /// Loads prefixes, padding and the counters reached so far.
  Future<Result<NumberingSettings>> load();

  /// Saves prefixes and padding. Counters are untouched.
  Future<Result<void>> save(NumberingSettings settings);

  /// Raises the counter of [kind] so that the next number is [nextNumber].
  ///
  /// Fails with a `ValidationFailure` when that would not move the counter
  /// forward: numbers are never reused.
  Future<Result<void>> advanceTo(DocumentKind kind, int nextNumber);
}
