import 'package:inventrix/core/result/result.dart';

/// The name of the local operator recorded on audit events. It is a label
/// the business chooses, not a verified identity.
abstract interface class AuditOperatorRepository {
  /// The current name, or `null` when none is set.
  Future<Result<String?>> name();

  /// Saves [name]; `null` clears it (events then name the device).
  Future<Result<void>> save(String? name, DateTime now);
}
