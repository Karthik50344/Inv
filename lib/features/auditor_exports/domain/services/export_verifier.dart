import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:inventrix/features/auditor_exports/domain/services/byte_hasher.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_package_builder.dart';

/// The result of checking a package.
final class ExportVerification extends Equatable {
  /// Creates a result.
  const ExportVerification({required this.problems, required this.filesChecked});

  /// What is wrong (empty when the package is intact).
  final List<String> problems;

  /// Files whose hash was compared.
  final int filesChecked;

  /// Whether the package is intact.
  bool get isValid => problems.isEmpty;

  @override
  List<Object?> get props => [problems, filesChecked];
}

/// Checks a package against its own checksums and manifest. It shows the
/// package was not changed after export; it cannot show who made it.
final class ExportPackageVerifier {
  /// Creates a verifier.
  const ExportPackageVerifier(this._hasher);

  final ByteHasher _hasher;

  /// Verifies [files] (path to bytes).
  ExportVerification verify(Map<String, Uint8List> files) {
    final problems = <String>[];
    final root = _root(files.keys);
    String at(String path) => root.isEmpty ? path : '$root/$path';

    for (final path in files.keys) {
      if (path.startsWith('/') || path.split('/').contains('..')) {
        problems.add('Unsafe file path: $path');
      }
    }
    final sumsBytes = files[at(ExportPackageBuilder.checksumsPath)];
    if (sumsBytes == null) {
      problems.add('The checksum list is missing.');
    }
    final manifestBytes = files[at(ExportPackageBuilder.manifestPath)];
    if (manifestBytes == null) {
      problems.add('The manifest is missing.');
    }
    if (sumsBytes == null || manifestBytes == null) {
      return ExportVerification(problems: problems, filesChecked: 0);
    }

    final listed = <String, String>{};
    for (final line in utf8.decode(sumsBytes).split('\n')) {
      if (line.isEmpty) {
        continue;
      }
      final split = line.indexOf('  ');
      if (split != 64) {
        problems.add('Malformed checksum line: $line');
        continue;
      }
      listed[line.substring(split + 2)] = line.substring(0, split);
    }

    var checked = 0;
    for (final entry in listed.entries) {
      final bytes = files[entry.key];
      if (bytes == null) {
        problems.add('Missing file: ${entry.key}');
        continue;
      }
      checked++;
      if (_hasher.sha256Hex(bytes) != entry.value) {
        problems.add('Changed file: ${entry.key}');
      }
    }
    final checksumsFile = at(ExportPackageBuilder.checksumsPath);
    for (final path in files.keys) {
      if (path != checksumsFile && !listed.containsKey(path)) {
        problems.add('File not in the checksum list: $path');
      }
    }

    try {
      final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
      for (final f in (manifest['files']! as List<Object?>).cast<Map<String, Object?>>()) {
        final path = f['path']! as String;
        final bytes = files[path];
        if (bytes == null) {
          problems.add('Manifest lists a missing file: $path');
        } else if (_hasher.sha256Hex(bytes) != f['sha256']) {
          problems.add('Manifest hash differs: $path');
        }
      }
    } on Object {
      problems.add('The manifest cannot be read.');
    }
    return ExportVerification(problems: problems, filesChecked: checked);
  }

  /// A single top-level folder holding `manifest.json`, or empty.
  String _root(Iterable<String> paths) {
    if (paths.contains(ExportPackageBuilder.manifestPath)) {
      return '';
    }
    for (final path in paths) {
      if (path.endsWith('/${ExportPackageBuilder.manifestPath}') &&
          path.split('/').length == 2) {
        return path.split('/').first;
      }
    }
    return '';
  }
}
