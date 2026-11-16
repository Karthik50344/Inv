import 'package:inventrix/features/backup/domain/entities/backup_format.dart';

/// Decides whether an archive entry name is safe and belongs in a backup.
///
/// This is the first defence against ZIP path traversal ("zip slip"): a name
/// is checked **before** any file is written, and anything that is not part
/// of the documented layout is refused instead of ignored.
abstract final class ArchivePathRules {
  static final RegExp _driveLetter = RegExp('^[A-Za-z]:');

  /// Returns `null` when [name] is acceptable, otherwise a short reason.
  static String? check(String name) {
    if (name.isEmpty) {
      return 'an entry has no name';
    }
    if (name.length > BackupFormat.maxNameLength) {
      return 'an entry name is too long';
    }
    for (final unit in name.codeUnits) {
      if (unit < 0x20 || unit == 0x7f) {
        return 'an entry name contains control characters';
      }
    }
    if (name.contains(r'\')) {
      return 'an entry name contains a backslash';
    }
    if (name.startsWith('/') || _driveLetter.hasMatch(name)) {
      return 'an entry has an absolute path';
    }
    if (name.contains(':')) {
      return 'an entry name contains a colon';
    }
    final trimmed = name.endsWith('/')
        ? name.substring(0, name.length - 1)
        : name;
    final segments = trimmed.split('/');
    for (final segment in segments) {
      if (segment.isEmpty) {
        return 'an entry name contains an empty folder name';
      }
      if (segment == '.' || segment == '..') {
        return 'an entry tries to leave the backup folder';
      }
    }
    return _checkLayout(segments, isDirectory: name.endsWith('/'));
  }

  static String? _checkLayout(
    List<String> segments, {
    required bool isDirectory,
  }) {
    final root = segments.first;
    switch (root) {
      case 'manifest.json':
        return segments.length == 1 && !isDirectory
            ? null
            : 'an entry is not part of the backup layout';
      case 'database':
        if (segments.length == 1) {
          return isDirectory ? null : 'an entry is not part of the layout';
        }
        return segments.length == 2 &&
                '${segments[0]}/${segments[1]}' == BackupFormat.databasePath &&
                !isDirectory
            ? null
            : 'an entry is not part of the backup layout';
      case 'metadata':
        return null;
      case 'attachments':
        if (segments.length == 1) {
          return null;
        }
        return BackupDataFolders.all.contains(segments[1])
            ? null
            : 'an attachment folder is not recognised';
      default:
        return 'an entry is not part of the backup layout';
    }
  }

  /// Whether [name] denotes a directory entry.
  static bool isDirectory(String name) => name.endsWith('/');

  /// Case-folded form used to detect duplicate entries.
  static String duplicateKey(String name) => name.toLowerCase();
}
