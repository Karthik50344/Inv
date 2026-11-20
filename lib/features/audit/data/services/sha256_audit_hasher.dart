import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';

/// SHA-256 over the UTF-8 bytes, as lowercase hex.
final class Sha256AuditHasher implements AuditHasher {
  /// Creates the hasher.
  const Sha256AuditHasher();

  @override
  String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();
}
