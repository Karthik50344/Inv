import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/export_history_use_cases.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the export history and of one export's detail screen.
final class ExportListState extends Equatable {
  /// Creates the state.
  const ExportListState({
    this.status = ViewStatus.initial,
    this.records = const [],
    this.busyId,
    this.message,
    this.messageSerial = 0,
    this.error,
  });

  /// Loading state.
  final ViewStatus status;

  /// Exports, newest first.
  final List<ExportRecord> records;

  /// The export an action is running on.
  final String? busyId;

  /// A short result message.
  final String? message;

  /// Changes with every message so the same text can be shown twice.
  final int messageSerial;

  /// A readable load error.
  final String? error;

  /// Copy with changes.
  ExportListState copyWith({
    ViewStatus? status,
    List<ExportRecord>? records,
    String? busyId,
    bool clearBusy = false,
    String? message,
    String? error,
  }) => ExportListState(
    status: status ?? this.status,
    records: records ?? this.records,
    busyId: clearBusy ? null : busyId ?? this.busyId,
    message: message,
    messageSerial: message == null ? messageSerial : messageSerial + 1,
    error: error,
  );

  @override
  List<Object?> get props => [status, records, busyId, message, messageSerial, error];
}

/// Lists exports and runs actions on them (verify, share, remove the file).
/// Used by the history screen and, with [only], by the detail screen.
class ExportListCubit extends Cubit<ExportListState> {
  /// Creates the cubit.
  ExportListCubit({
    required ListExportHistory list,
    required ExportHistoryRepository history,
    required VerifyExportFile verify,
    required ShareExportFile share,
    required DeleteExportFile deleteFile,
    this.only,
  }) : _list = list,
       _history = history,
       _verify = verify,
       _share = share,
       _delete = deleteFile,
       super(const ExportListState());

  final ListExportHistory _list;
  final ExportHistoryRepository _history;
  final VerifyExportFile _verify;
  final ShareExportFile _share;
  final DeleteExportFile _delete;

  /// When set, only this export is loaded (detail screen).
  final String? only;

  /// Loads the records.
  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final id = only;
    if (id != null) {
      final one = await _history.getById(id);
      final record = one.valueOrNull;
      emit(
        record == null
            ? ExportListState(
                status: ViewStatus.failure,
                error: one.failureOrNull?.message ?? 'This export no longer exists.',
              )
            : ExportListState(status: ViewStatus.loaded, records: [record]),
      );
      return;
    }
    final result = await _list();
    final records = result.valueOrNull;
    if (records == null) {
      emit(
        ExportListState(
          status: ViewStatus.failure,
          error: result.failureOrNull?.message ?? 'Could not load the exports.',
        ),
      );
      return;
    }
    emit(
      ExportListState(
        status: records.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        records: records,
      ),
    );
  }

  /// Checks the saved file again.
  Future<void> verify(String id) async {
    emit(state.copyWith(busyId: id));
    final result = await _verify(id);
    await _refresh();
    emit(
      state.copyWith(
        clearBusy: true,
        message: result.isFailure
            ? result.failureOrNull!.message
            : result.valueOrNull == 'verified'
            ? 'The file is exactly as it was when it was created.'
            : 'The file has changed or is missing. Do not rely on it.',
      ),
    );
  }

  /// Opens the share sheet or the save dialog.
  Future<void> share(String id, ExportMode mode) async {
    emit(state.copyWith(busyId: id));
    final result = await _share(id, mode);
    final done = result.valueOrNull;
    emit(
      state.copyWith(
        clearBusy: true,
        message: result.isFailure
            ? result.failureOrNull!.message
            : done != null && done.completed
            ? (mode == ExportMode.share ? 'Shared.' : 'Saved.')
            : null,
      ),
    );
  }

  /// Removes the file from the device; the record stays.
  Future<void> deleteFile(String id) async {
    emit(state.copyWith(busyId: id));
    final result = await _delete(id);
    await _refresh();
    emit(
      state.copyWith(
        clearBusy: true,
        message: result.isFailure
            ? result.failureOrNull!.message
            : 'The file was removed from this device.',
      ),
    );
  }

  Future<void> _refresh() async {
    final id = only;
    if (id != null) {
      final one = (await _history.getById(id)).valueOrNull;
      if (one != null) {
        emit(state.copyWith(records: [one]));
      }
      return;
    }
    final records = (await _list()).valueOrNull;
    if (records != null) {
      emit(state.copyWith(records: records));
    }
  }
}
