import 'package:inventrix/core/security/database_key.dart';

/// The unlocked database: where it lives and the key that opens it.
final class DatabaseSession {
  /// Creates a session.
  const DatabaseSession({required this.path, required this.key});

  /// Absolute path of the live database file.
  final String path;

  /// Key of the live database. Kept in memory only.
  final SecretKey256 key;
}
