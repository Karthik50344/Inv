import 'dart:typed_data';

/// SHA-256 of bytes, as lowercase hex. Implemented in the data layer.
abstract interface class ByteHasher {
  /// The SHA-256 digest of [bytes].
  String sha256Hex(Uint8List bytes);
}
