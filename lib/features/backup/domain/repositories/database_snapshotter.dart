import 'package:inventrix/core/result/result.dart';

/// Writes a consistent copy of the live database.
abstract interface class DatabaseSnapshotter {
  /// Writes a transactionally consistent snapshot of the open database to
  /// [targetPath], which must not exist yet. A raw file copy of a database
  /// that is in use is **not** acceptable; implementations use SQLite's own
  /// snapshot mechanism (`VACUUM INTO`).
  Future<Result<void>> snapshotTo(String targetPath);
}
