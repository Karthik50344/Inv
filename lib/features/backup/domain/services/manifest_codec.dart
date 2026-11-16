import 'dart:convert';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/entities/backup_manifest.dart';
import 'package:inventrix/features/backup/domain/services/archive_path_rules.dart';

/// Reads and writes `manifest.json`, validating everything it reads: a
/// manifest comes from a file the user picked and is never trusted.
abstract final class ManifestCodec {
  static final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');

  /// Serialises [manifest] as indented JSON.
  static String encode(BackupManifest manifest) =>
      const JsonEncoder.withIndent('  ').convert({
        'application': BackupFormat.application,
        'formatVersion': manifest.formatVersion,
        'appVersion': manifest.appVersion,
        'schemaVersion': manifest.schemaVersion,
        'createdAt': manifest.createdAt.toUtc().toIso8601String(),
        'files': [
          for (final entry in manifest.entries)
            {
              'path': entry.path,
              'sha256': entry.sha256,
              'sizeBytes': entry.sizeBytes,
            },
        ],
      });

  /// Parses and validates [source].
  static Result<BackupManifest> decode(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      return _invalid('the manifest is not valid JSON');
    }
    if (json is! Map<String, Object?>) {
      return _invalid('the manifest has the wrong shape');
    }
    if (json['application'] != BackupFormat.application) {
      return const Result.failure(
        RestoreFailure('This file is not an Inventrix backup.'),
      );
    }
    final format = json['formatVersion'];
    final schema = json['schemaVersion'];
    final appVersion = json['appVersion'];
    final created = json['createdAt'];
    final files = json['files'];
    if (format is! int || format < 1) {
      return _invalid('the manifest has no valid format version');
    }
    if (schema is! int || schema < 1) {
      return _invalid('the manifest has no valid schema version');
    }
    if (appVersion is! String || appVersion.isEmpty) {
      return _invalid('the manifest has no app version');
    }
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    if (createdAt == null) {
      return _invalid('the manifest has no valid creation time');
    }
    if (files is! List<Object?>) {
      return _invalid('the manifest has no file list');
    }
    if (files.length > BackupFormat.maxEntries) {
      return _invalid('the backup contains too many files');
    }

    final entries = <ManifestEntry>[];
    final seen = <String>{};
    var total = 0;
    for (final raw in files) {
      if (raw is! Map<String, Object?>) {
        return _invalid('a file entry has the wrong shape');
      }
      final path = raw['path'];
      final sha = raw['sha256'];
      final size = raw['sizeBytes'];
      if (path is! String) {
        return _invalid('a file entry has no path');
      }
      final problem = ArchivePathRules.check(path);
      if (problem != null) {
        return _invalid(problem);
      }
      if (ArchivePathRules.isDirectory(path) ||
          path == BackupFormat.manifestPath) {
        return _invalid('the file list contains an invalid path');
      }
      if (sha is! String || !_sha256.hasMatch(sha)) {
        return _invalid('a file entry has an invalid checksum');
      }
      if (size is! int || size < 0) {
        return _invalid('a file entry has an invalid size');
      }
      if (!seen.add(ArchivePathRules.duplicateKey(path))) {
        return _invalid('a file is listed twice');
      }
      total += size;
      entries.add(ManifestEntry(path: path, sha256: sha, sizeBytes: size));
    }
    if (total > BackupFormat.maxTotalBytes) {
      return _invalid('the backup is larger than allowed');
    }
    if (!seen.contains(
      ArchivePathRules.duplicateKey(BackupFormat.databasePath),
    )) {
      return _invalid('the manifest lists no database');
    }
    return Result.success(
      BackupManifest(
        formatVersion: format,
        appVersion: appVersion,
        schemaVersion: schema,
        createdAt: createdAt.toUtc(),
        entries: List.unmodifiable(entries),
      ),
    );
  }

  static Result<BackupManifest> _invalid(String reason) => Result.failure(
    RestoreFailure('This backup cannot be used: $reason.', cause: reason),
  );
}
