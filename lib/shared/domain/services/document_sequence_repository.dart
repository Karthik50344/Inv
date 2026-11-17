import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';

/// Allocates gap-free, strictly increasing numbers per document kind.
abstract interface class DocumentSequenceRepository {
  /// Returns the next number (1, 2, 3, ...) for [key].
  ///
  /// Must be called inside `TransactionRunner.runResult` together with the
  /// write that uses the number: if that transaction rolls back, the number
  /// is not consumed, so numbering has no gaps.
  Future<Result<int>> next(String key);

  /// Allocates the next number of [kind] and returns it formatted with the
  /// prefix and width currently configured in the settings
  /// (for example `INV-000042`).
  ///
  /// The same transaction rule as [next] applies. The prefix is read at the
  /// moment of posting, so changing it never touches numbers already issued.
  Future<Result<String>> nextNumber(DocumentKind kind);
}
