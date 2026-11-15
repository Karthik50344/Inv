import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';

/// A file copied into app storage.
final class StoredAttachment extends Equatable {
  /// Creates the description of a stored file.
  const StoredAttachment({
    required this.relativePath,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
  });

  /// Path relative to the application directory.
  final String relativePath;

  /// Original file name.
  final String fileName;

  /// MIME type derived from the extension.
  final String? mimeType;

  /// Size in bytes.
  final int sizeBytes;

  @override
  List<Object?> get props => [relativePath, fileName, mimeType, sizeBytes];
}

/// Stores attachments (receipts) inside the app's private storage.
///
/// Stored paths are **relative** because the absolute application directory
/// can change between app updates on iOS.
abstract interface class AttachmentStorage {
  /// Copies the picked file at [sourcePath] into app storage. Fails with
  /// `ValidationFailure` for unsupported or oversized files.
  Future<Result<StoredAttachment>> store(String sourcePath);

  /// Resolves a stored relative path to an absolute file path.
  Future<String> resolvePath(String relativePath);

  /// Deletes a stored file. Never throws: a missing file is fine.
  Future<void> delete(String relativePath);
}
