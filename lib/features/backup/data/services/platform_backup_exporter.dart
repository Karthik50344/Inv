import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';

/// [BackupExporter] using the system share sheet or a "save as" dialog.
final class PlatformBackupExporter implements BackupExporter {
  /// Creates the exporter.
  PlatformBackupExporter();

  final Logger _log = Logger('PlatformBackupExporter');

  @override
  Future<Result<ExportResult>> export({
    required String path,
    required String fileName,
    required ExportMode mode,
  }) async {
    try {
      switch (mode) {
        case ExportMode.share:
          final result = await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'application/zip', name: fileName)],
              subject: fileName,
            ),
          );
          return Result.success(
            ExportResult(
              completed: result.status != ShareResultStatus.dismissed,
            ),
          );
        case ExportMode.saveToDevice:
          // The picker writes the bytes itself on mobile, where it cannot
          // copy from a path.
          final bytes = await File(path).readAsBytes();
          final saved = await FilePicker.saveFile(
            dialogTitle: 'Save backup',
            fileName: fileName,
            bytes: bytes,
            type: FileType.custom,
            allowedExtensions: const ['zip'],
          );
          return Result.success(
            ExportResult(completed: saved != null, destination: saved),
          );
      }
    } on Object catch (error, stackTrace) {
      _log.warning('Export failed', error, stackTrace);
      return Result.failure(
        BackupFailure(
          'The backup could not be exported.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
