import 'dart:io';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// [LogoStorage] that copies the logo into `<documents>/product_images/`.
///
/// That folder is already part of every backup (see
/// `docs/workflows/backup_restore.md`), so the logo is backed up and
/// restored without a new archive layout. Logo files are named `logo_*` and
/// this class only ever deletes files with that prefix.
final class FileLogoStorage implements LogoStorage {
  /// Creates the storage. [baseDirectory] is injectable for tests.
  FileLogoStorage({
    required IdGenerator ids,
    required Clock clock,
    Future<Directory> Function()? baseDirectory,
  }) : _ids = ids,
       _clock = clock,
       _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  static const String _folder = 'product_images';
  static const String _prefix = 'logo_';
  static const int _maxBytes = 5 * 1024 * 1024;
  static const Set<String> _extensions = {'.jpg', '.jpeg', '.png'};

  final IdGenerator _ids;
  final Clock _clock;
  final Future<Directory> Function() _baseDirectory;
  final Logger _log = Logger('FileLogoStorage');

  @override
  Future<Result<String>> store(String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    if (!_extensions.contains(extension)) {
      return const Result.failure(
        ValidationFailure('Choose a JPG or PNG image for the logo.'),
      );
    }
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return const Result.failure(NotFoundFailure('Image file not found.'));
      }
      if (await source.length() > _maxBytes) {
        return const Result.failure(
          ValidationFailure('The logo must be smaller than 5 MB.'),
        );
      }
      final base = await _baseDirectory();
      final folder = Directory(p.join(base.path, _folder));
      await folder.create(recursive: true);
      final name =
          '$_prefix${_clock.now().millisecondsSinceEpoch}_${_ids.newId()}'
          '$extension';
      await source.copy(p.join(folder.path, name));
      return Result.success('$_folder/$name');
    } on FileSystemException catch (error, stackTrace) {
      _log.warning('Could not store logo', error, stackTrace);
      return Result.failure(
        UnexpectedFailure(
          'Could not save the logo.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<String> resolvePath(String relativePath) async =>
      p.join((await _baseDirectory()).path, relativePath);

  @override
  Future<List<int>?> read(String relativePath) async {
    if (!_isLogoPath(relativePath)) {
      return null;
    }
    try {
      final file = File(await resolvePath(relativePath));
      return await file.exists() ? await file.readAsBytes() : null;
    } on FileSystemException catch (error, stackTrace) {
      _log.warning('Could not read logo', error, stackTrace);
      return null;
    }
  }

  @override
  Future<void> delete(String relativePath) async {
    if (!_isLogoPath(relativePath)) {
      return;
    }
    try {
      final file = File(await resolvePath(relativePath));
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      _log.warning('Could not delete logo', error, stackTrace);
    }
  }

  /// Only files this storage created, directly inside its folder.
  static bool _isLogoPath(String relativePath) {
    final normalized = relativePath.replaceAll(r'\', '/');
    final parts = normalized.split('/');
    return parts.length == 2 &&
        parts[0] == _folder &&
        parts[1].startsWith(_prefix) &&
        !parts[1].contains('..');
  }
}
