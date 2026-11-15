import 'dart:io';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// [ImageStorage] that copies images into `<documents>/product_images/`.
final class FileImageStorage implements ImageStorage {
  /// Creates the storage. [baseDirectory] is injectable for tests.
  FileImageStorage({
    required IdGenerator ids,
    required Clock clock,
    Future<Directory> Function()? baseDirectory,
  }) : _ids = ids,
       _clock = clock,
       _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  static const String _folder = 'product_images';
  static const int _maxBytes = 10 * 1024 * 1024;
  static const Set<String> _extensions = {'.jpg', '.jpeg', '.png', '.webp'};

  final IdGenerator _ids;
  final Clock _clock;
  final Future<Directory> Function() _baseDirectory;
  final Logger _log = Logger('FileImageStorage');

  @override
  Future<Result<String>> storeProductImage(String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    if (!_extensions.contains(extension)) {
      return const Result.failure(
        ValidationFailure('Choose a JPG, PNG or WebP image.'),
      );
    }
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return const Result.failure(NotFoundFailure('Image file not found.'));
      }
      if (await source.length() > _maxBytes) {
        return const Result.failure(
          ValidationFailure('The image must be smaller than 10 MB.'),
        );
      }
      final base = await _baseDirectory();
      final folder = Directory(p.join(base.path, _folder));
      await folder.create(recursive: true);
      final name =
          '${_clock.now().millisecondsSinceEpoch}_${_ids.newId()}$extension';
      await source.copy(p.join(folder.path, name));
      return Result.success('$_folder/$name');
    } on FileSystemException catch (error, stackTrace) {
      _log.warning('Could not store image', error, stackTrace);
      return Result.failure(
        UnexpectedFailure(
          'Could not save the image.',
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
}
