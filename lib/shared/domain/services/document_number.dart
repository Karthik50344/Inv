/// Formats sequential document numbers such as `PUR-000042`.
abstract final class DocumentNumber {
  /// Number of digits the counter is padded to unless configured otherwise.
  static const int width = 6;

  /// Fewest and most digits the counter may be padded to.
  static const int minWidth = 3;

  /// See [minWidth].
  static const int maxWidth = 10;

  /// Longest accepted prefix.
  static const int maxPrefixLength = 10;

  /// Formats [sequence] with [prefix], padded to [padding] digits; numbers
  /// beyond the padding width simply grow (`PUR-1000000`).
  static String format(String prefix, int sequence, {int padding = width}) {
    if (sequence < 1) {
      throw ArgumentError.value(sequence, 'sequence', 'must be at least 1');
    }
    return '$prefix${sequence.toString().padLeft(padding, '0')}';
  }

  /// Why [prefix] cannot be used, or `null` when it is valid.
  ///
  /// A prefix is 1-10 letters, digits, `-`, `_`, `/` or `.` and must **not
  /// end in a digit**. That last rule keeps numbers unambiguous: the counter
  /// is the trailing run of digits, so two different (prefix, counter) pairs
  /// can never print the same number, however the prefix is changed later.
  static String? validatePrefix(String prefix) {
    if (prefix.isEmpty) {
      return 'Enter a prefix, for example INV-.';
    }
    if (prefix.length > maxPrefixLength) {
      return 'Use at most $maxPrefixLength characters.';
    }
    if (!RegExp(r'^[A-Za-z0-9_./-]+$').hasMatch(prefix)) {
      return 'Use only letters, digits and - _ / .';
    }
    if (RegExp(r'[0-9]$').hasMatch(prefix)) {
      return 'The prefix must not end with a digit (try ${prefix}-).';
    }
    return null;
  }

  /// Why [padding] is not a valid width, or `null`.
  static String? validatePadding(int padding) =>
      padding < minWidth || padding > maxWidth
      ? 'Use between $minWidth and $maxWidth digits.'
      : null;
}
