import 'dart:async';

/// Groups the audit events of one business operation.
///
/// The transaction runner opens a correlation scope around every database
/// transaction, so all events written while posting an invoice (the document,
/// its stock movements, its payment allocations) share one correlation id
/// without any use case passing it around.
abstract final class AuditCorrelation {
  static const Symbol _key = #inventrixAuditCorrelationId;

  /// The correlation id of the running operation, or `null` outside one.
  static String? get current => Zone.current[_key] as String?;

  /// Runs [body] with correlation [id]. An already running operation keeps
  /// its own id (nested transactions belong to the outer operation).
  static T run<T>(String id, T Function() body) {
    if (current != null) {
      return body();
    }
    return runZoned(body, zoneValues: {_key: id});
  }
}
