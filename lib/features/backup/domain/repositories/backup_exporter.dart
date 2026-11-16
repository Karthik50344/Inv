import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';

/// How a backup leaves the app.
enum ExportMode {
  /// Open the system share sheet (cloud drives, e-mail, other apps).
  share,

  /// Let the user pick a file name and location on the device.
  saveToDevice,
}

/// Outcome of an export.
final class ExportResult extends Equatable {
  /// Creates a result.
  const ExportResult({required this.completed, this.destination});

  /// `false` when the user dismissed the dialog.
  final bool completed;

  /// Where the file was saved, if known.
  final String? destination;

  @override
  List<Object?> get props => [completed, destination];
}

/// Hands a backup archive to the user.
abstract interface class BackupExporter {
  /// Exports the archive at [path] as [fileName].
  Future<Result<ExportResult>> export({
    required String path,
    required String fileName,
    required ExportMode mode,
  });
}
