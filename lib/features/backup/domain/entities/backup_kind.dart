/// Why a backup history row exists.
enum BackupKind {
  /// A backup the user asked for.
  backup('backup', 'Backup'),

  /// The automatic backup taken just before a restore.
  safety('safety', 'Safety copy'),

  /// A restore operation (no archive of its own).
  restore('restore', 'Restore');

  const BackupKind(this.value, this.label);

  /// Stored value.
  final String value;

  /// Label for the UI.
  final String label;

  /// Parses a stored [value]; throws [ArgumentError] for unknown values.
  static BackupKind fromValue(String value) => values.firstWhere(
    (kind) => kind.value == value,
    orElse: () => throw ArgumentError.value(value, 'value', 'Unknown kind'),
  );
}

/// Result of an operation recorded in the history.
enum BackupOutcome {
  /// Completed.
  success('success'),

  /// Failed or rolled back; nothing was lost.
  failed('failed');

  const BackupOutcome(this.value);

  /// Stored value.
  final String value;

  /// Parses a stored [value]; throws [ArgumentError] for unknown values.
  static BackupOutcome fromValue(String value) => values.firstWhere(
    (outcome) => outcome.value == value,
    orElse: () => throw ArgumentError.value(value, 'value', 'Unknown outcome'),
  );
}
