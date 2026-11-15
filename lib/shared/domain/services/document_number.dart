/// Formats sequential document numbers such as `PUR-000042`.
abstract final class DocumentNumber {
  /// Number of digits the counter is padded to.
  static const int width = 6;

  /// Formats [sequence] with [prefix]; numbers beyond the padding width
  /// simply grow (`PUR-1000000`).
  static String format(String prefix, int sequence) {
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'must be at least 1');
    }
    return '$prefix${sequence.toString().padLeft(width, '0')}';
  }
}
