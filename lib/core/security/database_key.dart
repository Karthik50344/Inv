import 'dart:math';
import 'dart:typed_data';

/// A 256-bit secret key (database key, backup device key, ...).
///
/// The key is only ever written to platform secure storage. [toString] never
/// shows the bytes, so the key cannot leak into logs by accident.
final class SecretKey256 {
  /// Wraps [bytes], which must be exactly [length] bytes.
  SecretKey256(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    if (_bytes.length != length) {
      throw ArgumentError.value(_bytes.length, 'bytes.length', 'Must be 32');
    }
  }

  /// Creates a key from 64 hexadecimal characters; `null` when malformed.
  static SecretKey256? tryParseHex(String hex) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
      return null;
    }
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return SecretKey256(bytes);
  }

  /// Generates a key from a cryptographically secure random source.
  factory SecretKey256.generate([Random? random]) {
    final source = random ?? Random.secure();
    return SecretKey256(List<int>.generate(length, (_) => source.nextInt(256)));
  }

  /// Key size in bytes.
  static const int length = 32;

  final Uint8List _bytes;

  /// A copy of the key bytes.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Lower-case hexadecimal form (64 characters).
  String toHex() =>
      _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// SQLCipher raw-key literal: `x'<64 hex>'`. Hex only, so it can be placed
  /// inside SQL text without escaping problems.
  String get sqlcipherRawKey => "x'${toHex()}'";

  /// Constant-time comparison.
  bool sameAs(SecretKey256 other) {
    var diff = 0;
    for (var i = 0; i < length; i++) {
      diff |= _bytes[i] ^ other._bytes[i];
    }
    return diff == 0;
  }

  @override
  bool operator ==(Object other) => other is SecretKey256 && sameAs(other);

  @override
  int get hashCode => Object.hashAll(_bytes);

  @override
  String toString() => 'SecretKey256(<redacted>)';
}
