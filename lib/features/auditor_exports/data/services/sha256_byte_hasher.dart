import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:inventrix/features/auditor_exports/domain/services/byte_hasher.dart';

/// SHA-256 of bytes.
final class Sha256ByteHasher implements ByteHasher {
  /// Creates the hasher.
  const Sha256ByteHasher();

  @override
  String sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();
}
