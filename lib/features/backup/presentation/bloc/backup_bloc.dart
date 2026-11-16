import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';
import 'package:inventrix/features/backup/domain/usecases/manage_backups.dart';
import 'package:inventrix/features/backup/domain/usecases/prepare_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/restore_backup.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// What the screen is busy doing.
enum BackupActivity {
  /// Nothing.
  idle,

  /// Writing a backup.
  creating,

  /// Sharing or saving a backup.
  exporting,

  /// Checking a backup file.
  validating,

  /// Replacing the data.
  restoring,
}

/// State of the backup screen.
final class BackupState extends Equatable {
  /// Creates a state.
  const BackupState({
    this.status = ViewStatus.initial,
    this.records = const [],
    this.activity = BackupActivity.idle,
    this.preview,
    this.message,
    this.error,
  });

  /// Loading status of the history.
  final ViewStatus status;

  /// History, newest first.
  final List<BackupRecord> records;

  /// Current operation.
  final BackupActivity activity;

  /// A validated backup waiting for the user's confirmation.
  final BackupPreview? preview;

  /// One-shot success message.
  final String? message;

  /// One-shot error message (user-safe).
  final String? error;

  /// Whether an operation is running.
  bool get busy => activity != BackupActivity.idle;

  /// Time of the latest successful manual backup.
  DateTime? get lastBackupAt {
    for (final record in records) {
      if (record.kind == BackupKind.backup &&
          record.outcome == BackupOutcome.success) {
        return record.createdAt;
      }
    }
    return null;
  }

  /// Copy; [message] and [error] are cleared unless given. Pass
  /// [clearPreview] to drop the preview.
  BackupState copyWith({
    ViewStatus? status,
    List<BackupRecord>? records,
    BackupActivity? activity,
    BackupPreview? preview,
    bool clearPreview = false,
    String? message,
    String? error,
  }) => BackupState(
    status: status ?? this.status,
    records: records ?? this.records,
    activity: activity ?? this.activity,
    preview: clearPreview ? null : (preview ?? this.preview),
    message: message,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    records,
    activity,
    preview,
    message,
    error,
  ];
}

/// Drives the backup and restore screen.
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  /// Creates the bloc.
  BackupBloc({
    required ListBackups listBackups,
    required CreateBackup createBackup,
    required ExportBackup exportBackup,
    required DeleteStoredBackup deleteBackup,
    required PrepareRestore prepareRestore,
    required DiscardStagedBackup discardStaged,
    required RestoreBackup restoreBackup,
    required BackupLocations locations,
  }) : _list = listBackups,
       _create = createBackup,
       _export = exportBackup,
       _delete = deleteBackup,
       _prepare = prepareRestore,
       _discard = discardStaged,
       _restore = restoreBackup,
       _locations = locations,
       super(const BackupState()) {
    on<BackupStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<BackupCreateRequested>(_onCreate, transformer: sequentialTransformer());
    on<BackupExportRequested>(_onExport, transformer: sequentialTransformer());
    on<BackupDeleteRequested>(_onDelete, transformer: sequentialTransformer());
    on<BackupFileSelected>(
      (event, emit) => _validate(event.path, emit),
      transformer: sequentialTransformer(),
    );
    on<BackupStoredSelected>(_onStored, transformer: sequentialTransformer());
    on<BackupPreviewDiscarded>(
      _onDiscard,
      transformer: sequentialTransformer(),
    );
    on<BackupRestoreConfirmed>(
      _onRestore,
      transformer: sequentialTransformer(),
    );
  }

  final ListBackups _list;
  final CreateBackup _create;
  final ExportBackup _export;
  final DeleteStoredBackup _delete;
  final PrepareRestore _prepare;
  final DiscardStagedBackup _discard;
  final RestoreBackup _restore;
  final BackupLocations _locations;

  Future<void> _load(Emitter<BackupState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _list();
    result.when(
      success: (records) => emit(
        state.copyWith(
          status: records.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
          records: records,
        ),
      ),
      failure: (failure) => emit(
        state.copyWith(status: ViewStatus.failure, error: failure.userMessage),
      ),
    );
  }

  Future<void> _onCreate(
    BackupCreateRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(activity: BackupActivity.creating));
    final result = await _create();
    await _refreshAfter(
      emit,
      result.when(
        success: (record) => 'Backup created: ${record.fileName}',
        failure: (_) => null,
      ),
      result.failureOrNull?.userMessage,
    );
  }

  Future<void> _onExport(
    BackupExportRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(activity: BackupActivity.exporting));
    final result = await _export(event.id, event.mode);
    await _refreshAfter(
      emit,
      result.valueOrNull == true ? 'Backup exported.' : null,
      result.failureOrNull?.userMessage,
    );
  }

  Future<void> _onDelete(
    BackupDeleteRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.busy) {
      return;
    }
    final result = await _delete(event.id);
    await _refreshAfter(
      emit,
      result.isSuccess ? 'Stored copy deleted.' : null,
      result.failureOrNull?.userMessage,
    );
  }

  Future<void> _onStored(
    BackupStoredSelected event,
    Emitter<BackupState> emit,
  ) async {
    final record = state.records.where((r) => r.id == event.id).firstOrNull;
    final stored = record?.storedPath;
    if (record == null || stored == null) {
      emit(state.copyWith(error: 'This backup has no stored copy.'));
      return;
    }
    await _validate(await _locations.resolveBackup(stored), emit);
  }

  Future<void> _validate(String path, Emitter<BackupState> emit) async {
    if (state.busy) {
      return;
    }
    final old = state.preview;
    if (old != null) {
      await _discard(old.staged);
    }
    emit(
      state.copyWith(activity: BackupActivity.validating, clearPreview: true),
    );
    final result = await _prepare(path);
    result.when(
      success: (preview) =>
          emit(state.copyWith(activity: BackupActivity.idle, preview: preview)),
      failure: (failure) => emit(
        state.copyWith(
          activity: BackupActivity.idle,
          error: failure.userMessage,
        ),
      ),
    );
  }

  Future<void> _onDiscard(
    BackupPreviewDiscarded event,
    Emitter<BackupState> emit,
  ) async {
    final preview = state.preview;
    if (preview == null || state.busy) {
      return;
    }
    await _discard(preview.staged);
    emit(state.copyWith(clearPreview: true));
  }

  Future<void> _onRestore(
    BackupRestoreConfirmed event,
    Emitter<BackupState> emit,
  ) async {
    final preview = state.preview;
    if (preview == null || state.busy) {
      return;
    }
    emit(state.copyWith(activity: BackupActivity.restoring, preview: preview));
    final Result<RestoreOutcome> result = await _restore(
      staged: preview.staged,
      confirmed: true,
    );
    // On success the whole app is rebuilt; this bloc is closed by then and
    // emit() is ignored, which is fine.
    result.when(
      success: (_) => emit(
        state.copyWith(activity: BackupActivity.idle, clearPreview: true),
      ),
      failure: (failure) => emit(
        state.copyWith(
          activity: BackupActivity.idle,
          clearPreview: true,
          error: failure.userMessage,
        ),
      ),
    );
  }

  Future<void> _refreshAfter(
    Emitter<BackupState> emit,
    String? message,
    String? error,
  ) async {
    final result = await _list();
    final records = result.valueOrNull ?? state.records;
    emit(
      state.copyWith(
        activity: BackupActivity.idle,
        status: records.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        records: records,
        message: message,
        error: error,
      ),
    );
  }
}
