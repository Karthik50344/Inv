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
  /// Creates the event. A [recoveryPassphrase] lets the backup be opened on
  /// another device; without one only this installation can open it.
  const BackupCreateRequested({this.recoveryPassphrase});

  /// Optional recovery passphrase (never stored).
  final String? recoveryPassphrase;

  @override
  List<Object?> get props => [recoveryPassphrase];
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
  const BackupFileSelected(this.path, {this.passphrase});

  /// Absolute path of the archive.
  final String path;

  /// Recovery passphrase, when the backup needs one.
  final String? passphrase;

  @override
  List<Object?> get props => [path, passphrase];
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

/// The user gave up entering a recovery passphrase.
final class BackupPassphraseCancelled extends BackupEvent {
  /// Creates the event.
  const BackupPassphraseCancelled();
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
