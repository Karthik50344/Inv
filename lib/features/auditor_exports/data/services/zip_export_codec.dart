import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';

/// ZIP reading and writing with the `archive` package.
final class ArchiveExportZipCodec implements ExportZipCodec {
  /// Creates the codec.
  const ArchiveExportZipCodec();

  @override
  Uint8List encode(Map<String, Uint8List> files) {
    final archive = Archive();
    final names = files.keys.toList()..sort();
    for (final name in names) {
      archive.addFile(ArchiveFile.bytes(name, files[name]!));
    }
    final List<int>? encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? const <int>[]);
  }

  @override
  Result<Map<String, Uint8List>> decode(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final files = <String, Uint8List>{};
      for (final file in archive.files) {
        if (!file.isFile) {
          continue;
        }
        final name = file.name;
        if (name.isEmpty ||
            name.startsWith('/') ||
            name.contains(r'\') ||
            name.split('/').contains('..')) {
          return Result.failure(ExportFailure('Unsafe path in the archive: $name'));
        }
        files[name] = file.readBytes() ?? Uint8List(0);
      }
      return Result.success(files);
    } on Object catch (error, stack) {
      return Result.failure(
        ExportFailure(
          'The archive cannot be read.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }
}
