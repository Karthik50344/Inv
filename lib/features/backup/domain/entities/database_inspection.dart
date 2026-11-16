import 'package:equatable/equatable.dart';

/// Result of checking a SQLite file.
final class DatabaseInspection extends Equatable {
  /// Creates an inspection result.
  const DatabaseInspection({
    required this.schemaVersion,
    required this.integrityMessages,
    required this.foreignKeyViolations,
    this.recordCounts = const {},
  });

  /// `PRAGMA user_version` (Drift's schema version).
  final int schemaVersion;

  /// Rows of `PRAGMA integrity_check`; a healthy database yields `['ok']`.
  final List<String> integrityMessages;

  /// Rows of `PRAGMA foreign_key_check`.
  final int foreignKeyViolations;

  /// Row counts of the main tables (only those that exist), for the
  /// confirmation screen.
  final Map<String, int> recordCounts;

  /// Whether the integrity check passed.
  bool get integrityOk =>
      integrityMessages.length == 1 && integrityMessages.first == 'ok';

  /// Whether nothing is wrong with the file.
  bool get isHealthy => integrityOk && foreignKeyViolations == 0;

  /// Short description of the problem, or `null` when healthy.
  String? get problem {
    if (!integrityOk) {
      return 'the database failed its integrity check';
    }
    if (foreignKeyViolations > 0) {
      return 'the database contains broken references '
          '($foreignKeyViolations)';
    }
    return null;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    integrityMessages,
    foreignKeyViolations,
    recordCounts,
  ];
}
