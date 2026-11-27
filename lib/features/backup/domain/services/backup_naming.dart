import 'package:inventrix/features/backup/domain/entities/backup_format.dart';

/// Names of backup archives.
abstract final class BackupNaming {
  /// `inventrix_backup_20261115_143012.ivxbak` for 2026-11-15 14:30:12 UTC.
  ///
  /// [suffix] distinguishes archives created within the same second (for
  /// example the safety copy and a manual backup).
  static String fileName(
    DateTime at, {
    String prefix = 'inventrix_backup',
    int? suffix,
  }) {
    final utc = at.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
        '_${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
    return '${prefix}_$stamp${suffix == null ? '' : '_$suffix'}'
        '.${BackupFormat.fileExtension}';
  }

  /// Whether [name] is a plain file name (no folders), so it can be joined
  /// to the backups directory safely.
  static bool isPlainFileName(String name) =>
      name.isNotEmpty &&
      !name.contains('/') &&
      !name.contains(r'\') &&
      name != '.' &&
      name != '..' &&
      !name.contains('\u0000');
}
