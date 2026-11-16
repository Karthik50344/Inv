import 'package:equatable/equatable.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';

/// Events of [BackupBloc].
sealed class BackupEvent extends Equatable {
  const BackupEvent();

  @override
  List<Object?> get props => [];
}

/// Load (or reload) the history.
final class BackupStarted extends BackupEvent {
  /// Creates the event.
  const BackupStarted();
}

/// Create a backup now.
final class BackupCreateRequested extends BackupEvent {
  /// Creates the event.
  const BackupCreateRequested();
}

/// Share or save the stored copy of a backup.
final class BackupExportRequested extends BackupEvent {
  /// Creates the event.
  const BackupExportRequested(this.id, this.mode);

  /// Record id.
  final String id;

  /// How to export.
  final ExportMode mode;

  @override
  List<Object?> get props => [id, mode];
}

/// Delete the app's own copy of a backup.
final class BackupDeleteRequested extends BackupEvent {
  /// Creates the event.
  const BackupDeleteRequested(this.id);

  /// Record id.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// The user picked a backup file to restore.
final class BackupFileSelected extends BackupEvent {
  /// Creates the event.
  const BackupFileSelected(this.path);

  /// Absolute path of the archive.
  final String path;

  @override
  List<Object?> get props => [path];
}

/// The user chose a backup from the history to restore.
final class BackupStoredSelected extends BackupEvent {
  /// Creates the event.
  const BackupStoredSelected(this.id);

  /// Record id.
  final String id;

  @override
  List<Object?> get props => [id];
}

/// The user backed out of the confirmation.
final class BackupPreviewDiscarded extends BackupEvent {
  /// Creates the event.
  const BackupPreviewDiscarded();
}

/// The user confirmed the restore.
final class BackupRestoreConfirmed extends BackupEvent {
  /// Creates the event.
  const BackupRestoreConfirmed();
}
