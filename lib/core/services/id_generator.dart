/// Generates unique identifiers for new records.
abstract interface class IdGenerator {
  /// Returns a new unique id.
  String newId();
}
