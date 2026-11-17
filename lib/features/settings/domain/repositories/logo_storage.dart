import 'package:inventrix/core/result/result.dart';

/// Keeps the business logo inside the app's private storage.
///
/// Stored paths are relative to the application documents folder. The logo
/// lives in the image folder that backups already include, so restoring a
/// backup brings it back.
abstract interface class LogoStorage {
  /// Copies the picked image into app storage and returns its relative
  /// path. Fails with `ValidationFailure` for unsupported or oversized
  /// files.
  Future<Result<String>> store(String sourcePath);

  /// Absolute path of a stored logo, for display.
  Future<String> resolvePath(String relativePath);

  /// Reads the stored logo; `null` when the file is missing.
  Future<List<int>?> read(String relativePath);

  /// Deletes a logo this storage created earlier. Never throws.
  Future<void> delete(String relativePath);
}
