import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/entities/backup_manifest.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';
import 'package:inventrix/features/backup/domain/services/archive_path_rules.dart';
import 'package:inventrix/features/backup/domain/services/manifest_codec.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// [BackupPackager] that reads and writes ZIP files with the `archive`
/// package and checksums with `crypto`.
///
/// Reading is deliberately strict: every entry name is validated before any
/// file is created, links and unknown entries are refused, the archive must
/// match its manifest exactly, and every file is hashed.
final class ZipBackupPackager implements BackupPackager {
  /// Creates the packager.
  ZipBackupPackager();

  static const int _maxManifestBytes = 8 * 1024 * 1024;
  final Logger _log = Logger('ZipBackupPackager');

  // ---------------------------------------------------------------- pack

  @override
  Future<Result<PackedBackup>> pack(PackRequest request) async {
    final partial = File('${request.outputPath}.part');
    try {
      final sources = await _collectSources(request);
      if (sources case Err<List<_Source>>(:final failure)) {
        return Result.failure(failure);
      }
      final entries = <ManifestEntry>[];
      for (final source in sources.valueOrNull!) {
        entries.add(
          ManifestEntry(
            path: source.zipPath,
            sha256: await _hashFile(source.file),
            sizeBytes: await source.file.length(),
          ),
        );
      }
      final info = utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'application': BackupFormat.application,
          'appVersion': request.appVersion,
          'schemaVersion': request.schemaVersion,
          'createdAt': request.createdAt.toUtc().toIso8601String(),
          'attachmentCount': entries
              .where((e) => e.path.startsWith(BackupFormat.attachmentsPrefix))
              .length,
        }),
      );
      entries
        ..add(
          ManifestEntry(
            path: BackupFormat.metadataInfoPath,
            sha256: sha256.convert(info).toString(),
            sizeBytes: info.length,
          ),
        )
        ..sort((a, b) => a.path.compareTo(b.path));
      final manifest = BackupManifest(
        formatVersion: BackupFormat.formatVersion,
        appVersion: request.appVersion,
        schemaVersion: request.schemaVersion,
        createdAt: request.createdAt.toUtc(),
        entries: List.unmodifiable(entries),
      );

      await Directory(p.dirname(request.outputPath)).create(recursive: true);
      if (await partial.exists()) {
        await partial.delete();
      }
      final encoder = ZipFileEncoder()..create(partial.path);
      try {
        encoder
          ..addArchiveFile(
            ArchiveFile.string(
              BackupFormat.manifestPath,
              ManifestCodec.encode(manifest),
            ),
          )
          ..addArchiveFile(
            ArchiveFile.bytes(BackupFormat.metadataInfoPath, info),
          );
        for (final source in sources.valueOrNull!) {
          await encoder.addFile(source.file, source.zipPath);
        }
      } finally {
        await encoder.close();
      }
      await partial.rename(request.outputPath);
      final output = File(request.outputPath);
      return Result.success(
        PackedBackup(
          path: output.path,
          sizeBytes: await output.length(),
          sha256: await _hashFile(output),
          manifest: manifest,
        ),
      );
    } on Object catch (error, stackTrace) {
      _log.warning('Packing failed', error, stackTrace);
      await _deleteQuietly(partial);
      return Result.failure(
        BackupFailure(
          'Could not write the backup file. Check that the device has '
          'enough free space.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<Result<List<_Source>>> _collectSources(PackRequest request) async {
    final database = File(request.databasePath);
    if (!await database.exists()) {
      return const Result.failure(
        BackupFailure('The database snapshot is missing.'),
      );
    }
    final sources = <_Source>[_Source(BackupFormat.databasePath, database)];
    for (final folder in request.dataFolders) {
      final directory = Directory(folder.directoryPath);
      if (!await directory.exists()) {
        continue;
      }
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) {
          continue; // directories are implied; links are never followed
        }
        final relative = p.posix.joinAll(
          p.split(p.relative(entity.path, from: directory.path)),
        );
        final zipPath =
            '${BackupFormat.attachmentsPrefix}${folder.zipName}/$relative';
        final problem = ArchivePathRules.check(zipPath);
        if (problem != null) {
          return Result.failure(
            BackupFailure(
              'The file "${p.basename(entity.path)}" cannot be stored in a '
              'backup ($problem). Rename or remove it and try again.',
            ),
          );
        }
        sources.add(_Source(zipPath, entity));
      }
    }
    return Result.success(sources);
  }

  // ------------------------------------------------------------ checksum

  @override
  Future<Result<String>> archiveChecksum(String archivePath) async {
    try {
      return Result.success(await _hashFile(File(archivePath)));
    } on FileSystemException catch (error, stackTrace) {
      return Result.failure(
        NotFoundFailure(
          'The backup file could not be read.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // -------------------------------------------------------------- verify

  @override
  Future<Result<BackupManifest>> verify(String archivePath) async {
    InputFileStream? input;
    try {
      input = InputFileStream(archivePath);
      final archive = _decode(input);
      final checked = _validate(archive);
      if (checked case Err<_Checked>(:final failure)) {
        return Result.failure(failure);
      }
      final manifest = checked.valueOrNull!.manifest;
      for (final entry in manifest.entries) {
        final file = checked.valueOrNull!.files[entry.path]!;
        final bytes = file.readBytes() ?? Uint8List(0);
        final mismatch = _mismatch(
          entry,
          size: bytes.length,
          sha: sha256.convert(bytes).toString(),
        );
        file.clear();
        if (mismatch != null) {
          return Result.failure(mismatch);
        }
      }
      return Result.success(manifest);
    } on _ArchiveProblem catch (problem) {
      return Result.failure(problem.failure);
    } on Object catch (error, stackTrace) {
      return Result.failure(_unreadable(error, stackTrace));
    } finally {
      await input?.close();
    }
  }

  // -------------------------------------------------------------- unpack

  @override
  Future<Result<StagedBackup>> unpack({
    required String archivePath,
    required String stagingDirectory,
  }) async {
    final staging = Directory(stagingDirectory);
    InputFileStream? input;
    var ok = false;
    try {
      final source = File(archivePath);
      if (!await source.exists()) {
        return const Result.failure(
          NotFoundFailure('The backup file could not be found.'),
        );
      }
      if (!await staging.exists() || !(await staging.list().isEmpty)) {
        return const Result.failure(
          RestoreFailure('The restore workspace is not empty.'),
        );
      }
      final archiveSize = await source.length();
      final archiveSha = await _hashFile(source);

      input = InputFileStream(archivePath);
      final archive = _decode(input);
      final checked = _validate(archive);
      if (checked case Err<_Checked>(:final failure)) {
        return Result.failure(failure);
      }
      final manifest = checked.valueOrNull!.manifest;

      for (final entry in manifest.entries) {
        final target = _resolveInside(staging.path, entry.path);
        await Directory(p.dirname(target)).create(recursive: true);
        final zipFile = checked.valueOrNull!.files[entry.path]!;
        final out = OutputFileStream(target);
        try {
          zipFile.writeContent(out);
        } finally {
          await out.close();
        }
        final written = File(target);
        final mismatch = _mismatch(
          entry,
          size: await written.length(),
          sha: await _hashFile(written),
        );
        zipFile.clear();
        if (mismatch != null) {
          return Result.failure(mismatch);
        }
      }

      final folders = <String, String>{};
      for (final name in BackupDataFolders.all) {
        final directory = Directory(p.join(staging.path, 'attachments', name));
        if (await directory.exists()) {
          folders[name] = directory.path;
        }
      }
      ok = true;
      return Result.success(
        StagedBackup(
          manifest: manifest,
          directory: staging.path,
          databasePath: _resolveInside(staging.path, BackupFormat.databasePath),
          dataFolders: folders,
          sourceName: p.basename(archivePath),
          archiveSha256: archiveSha,
          archiveSizeBytes: archiveSize,
        ),
      );
    } on _ArchiveProblem catch (problem) {
      return Result.failure(problem.failure);
    } on Object catch (error, stackTrace) {
      _log.warning('Unpacking failed', error, stackTrace);
      return Result.failure(_unreadable(error, stackTrace));
    } finally {
      await input?.close();
      if (!ok) {
        await _emptyDirectory(staging);
      }
    }
  }

  // ------------------------------------------------------------- helpers

  Archive _decode(InputFileStream input) {
    try {
      return ZipDecoder().decodeStream(input, verify: true);
    } on Object catch (error, stackTrace) {
      throw _ArchiveProblem(
        RestoreFailure(
          'This file is not a valid backup: it is damaged or not a ZIP '
          'archive.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Validates names, links, duplicates and limits, then reads and checks
  /// the manifest against the list of entries.
  Result<_Checked> _validate(Archive archive) {
    if (archive.length > BackupFormat.maxEntries + 1) {
      return _bad('it contains too many files');
    }
    final files = <String, ArchiveFile>{};
    final seen = <String>{};
    ArchiveFile? manifestFile;
    var declared = 0;
    for (final file in archive) {
      final name = file.name;
      final problem = ArchivePathRules.check(name);
      if (problem != null) {
        return _bad(problem);
      }
      if (file.isSymbolicLink) {
        return _bad('it contains a link');
      }
      if (!seen.add(ArchivePathRules.duplicateKey(name))) {
        return _bad('it contains the same file twice');
      }
      if (ArchivePathRules.isDirectory(name) || !file.isFile) {
        continue;
      }
      declared += file.size;
      if (declared > BackupFormat.maxTotalBytes) {
        return _bad('it is larger than allowed');
      }
      if (name == BackupFormat.manifestPath) {
        manifestFile = file;
      } else {
        files[name] = file;
      }
    }
    if (manifestFile == null) {
      return _bad('it has no manifest');
    }
    if (manifestFile.size > _maxManifestBytes) {
      return _bad('its manifest is too large');
    }
    final String text;
    try {
      text = utf8.decode(manifestFile.readBytes() ?? Uint8List(0));
    } on FormatException {
      return _bad('its manifest is not text');
    }
    final decoded = ManifestCodec.decode(text);
    if (decoded case Err<BackupManifest>(:final failure)) {
      return Result.failure(failure);
    }
    final manifest = decoded.valueOrNull!;

    final listed = {for (final entry in manifest.entries) entry.path};
    for (final name in files.keys) {
      if (!listed.contains(name)) {
        return _bad('it contains a file that is not in its manifest');
      }
    }
    for (final entry in manifest.entries) {
      final file = files[entry.path];
      if (file == null) {
        return _bad('a file listed in its manifest is missing');
      }
      if (file.size != entry.sizeBytes) {
        return _bad('a file has a different size than its manifest says');
      }
    }
    return Result.success(_Checked(manifest, files));
  }

  Failure? _mismatch(
    ManifestEntry entry, {
    required int size,
    required String sha,
  }) {
    if (size != entry.sizeBytes || sha != entry.sha256) {
      return RestoreFailure(
        'This backup is damaged: "${p.posix.basename(entry.path)}" does not '
        'match its checksum.',
        cause: entry.path,
      );
    }
    return null;
  }

  Result<_Checked> _bad(String reason) => Result.failure(
    RestoreFailure('This backup cannot be used: $reason.', cause: reason),
  );

  RestoreFailure _unreadable(Object error, StackTrace stackTrace) =>
      RestoreFailure(
        'This backup could not be read. The file may be damaged or '
        'incomplete.',
        cause: error,
        stackTrace: stackTrace,
      );

  /// Joins [archivePath] below [root] and proves the result stays inside.
  String _resolveInside(String root, String archivePath) {
    final target = p.joinAll([root, ...archivePath.split('/')]);
    if (!p.isWithin(root, target)) {
      throw _ArchiveProblem(
        const RestoreFailure(
          'This backup cannot be used: an entry tries to leave the backup '
          'folder.',
        ),
      );
    }
    return target;
  }

  Future<String> _hashFile(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Nothing more can be done.
    }
  }

  Future<void> _emptyDirectory(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return;
      }
      await for (final entity in directory.list()) {
        await entity.delete(recursive: true);
      }
    } on FileSystemException {
      // The restore workspace is discarded by the caller anyway.
    }
  }
}

final class _Source {
  const _Source(this.zipPath, this.file);

  final String zipPath;
  final File file;
}

final class _Checked {
  const _Checked(this.manifest, this.files);

  final BackupManifest manifest;
  final Map<String, ArchiveFile> files;
}

/// Internal control-flow exception carrying a user-facing failure.
final class _ArchiveProblem implements Exception {
  const _ArchiveProblem(this.failure);

  final Failure failure;
}
