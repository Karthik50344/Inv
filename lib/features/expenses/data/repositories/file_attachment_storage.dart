import 'dart:io';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// [AttachmentStorage] that copies files into `<documents>/attachments/`.
final class FileAttachmentStorage implements AttachmentStorage {
  /// Creates the storage. [baseDirectory] is injectable for tests.
  FileAttachmentStorage({
    required IdGenerator ids,
    required Clock clock,
    Future<Directory> Function()? baseDirectory,
  }) : _ids = ids,
       _clock = clock,
       _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  static const String _folder = 'attachments';
  static const int _maxBytes = 10 * 1024 * 1024;
  static const Map<String, String> _mimeTypes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.pdf': 'application/pdf',
  };

  final IdGenerator _ids;
  final Clock _clock;
  final Future<Directory> Function() _baseDirectory;
  final Logger _log = Logger('FileAttachmentStorage');

  @override
  Future<Result<StoredAttachment>> store(String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    final mime = _mimeTypes[extension];
    if (mime == null) {
      return const Result.failure(
        ValidationFailure('Attach a JPG, PNG, WebP or PDF file.'),
      );
    }
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return const Result.failure(NotFoundFailure('File not found.'));
      }
      final size = await source.length();
      if (size > _maxBytes) {
        return const Result.failure(
          ValidationFailure('The file must be smaller than 10 MB.'),
        );
      }
      final base = await _baseDirectory();
      final folder = Directory(p.join(base.path, _folder));
      await folder.create(recursive: true);
      final name =
          '${_clock.now().millisecondsSinceEpoch}_${_ids.newId()}'
          '$extension';
      await source.copy(p.join(folder.path, name));
      return Result.success(
        StoredAttachment(
          relativePath: '$_folder/$name',
          fileName: p.basename(sourcePath),
          mimeType: mime,
          sizeBytes: size,
        ),
      );
    } on FileSystemException catch (error, stackTrace) {
      _log.warning('Could not store attachment', error, stackTrace);
      return Result.failure(
        UnexpectedFailure(
          'Could not save the file.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<String> resolvePath(String relativePath) async {
    final base = await _baseDirectory();
    return p.join(base.path, relativePath);
  }

  @override
  Future<void> delete(String relativePath) async {
    try {
      final file = File(await resolvePath(relativePath));
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      _log.warning('Could not delete attachment', error, stackTrace);
    }
  }
}
