import 'package:inventrix/core/result/result.dart';

/// Allocates gap-free, strictly increasing numbers per document kind.
abstract interface class DocumentSequenceRepository {
  /// Returns the next number (1, 2, 3, ...) for [key].
  ///
  /// Must be called inside `TransactionRunner.runResult` together with the
  /// write that uses the number: if that transaction rolls back, the number
  /// is not consumed, so numbering has no gaps.
  Future<Result<int>> next(String key);
}
