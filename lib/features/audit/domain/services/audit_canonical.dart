import 'dart:convert';

/// Deterministic serialisation used before hashing.
///
/// Map keys are sorted, there is no whitespace, `DateTime` becomes an ISO
/// UTC string, and only JSON-safe values are accepted, so the same data
/// always produces the same text on every device.
abstract final class AuditCanonical {
  /// The canonical JSON text of [value].
  static String encode(Object? value) => jsonEncode(_normalize(value));

  static Object? _normalize(Object? value) {
    if (value == null || value is bool || value is String || value is int) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw ArgumentError.value(value, 'value', 'must be finite');
      }
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map) {
      final entries = {
        for (final e in value.entries) e.key.toString(): e.value,
      };
      final keys = entries.keys.toList()..sort();
      return {for (final k in keys) k: _normalize(entries[k])};
    }
    if (value is Iterable) {
      return [for (final e in value) _normalize(e)];
    }
    throw ArgumentError.value(
      value,
      'value',
      'unsupported audit value type ${value.runtimeType}',
    );
  }
}

/// SHA-256 of a text, as lowercase hex. Implemented in the data layer.
abstract interface class AuditHasher {
  /// The SHA-256 digest of the UTF-8 bytes of [input].
  String sha256Hex(String input);
}
