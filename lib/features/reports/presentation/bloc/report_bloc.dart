import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/features/reports/domain/services/report_filter_options.dart';
import 'package:inventrix/features/reports/domain/usecases/build_report.dart';
import 'package:inventrix/features/reports/domain/usecases/export_report.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_event.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of a report screen.
final class ReportState extends Equatable {
  /// Creates a state.
  const ReportState({
    this.status = ViewStatus.initial,
    this.kind,
    this.period = ReportPeriod.thisMonth,
    this.filter,
    this.choices = const ReportFilterChoices(),
    this.document,
    this.exportStatus = SubmitStatus.idle,
    this.message,
  });

  /// Loading status. `empty` means the report has no rows.
  final ViewStatus status;

  /// The open report.
  final ReportKind? kind;

  /// Selected period preset.
  final ReportPeriod period;

  /// Active filter (range and optional product, customer or supplier).
  final ReportFilter? filter;

  /// Entries for the filter pickers.
  final ReportFilterChoices choices;

  /// The loaded report; kept while a reload is running.
  final ReportDocument? document;

  /// State of the CSV export.
  final SubmitStatus exportStatus;

  /// One-shot user-facing message (error or export result).
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  ReportState copyWith({
    ViewStatus? status,
    ReportKind? kind,
    ReportPeriod? period,
    ReportFilter? filter,
    ReportFilterChoices? choices,
    ReportDocument? document,
    SubmitStatus? exportStatus,
    String? message,
  }) => ReportState(
    status: status ?? this.status,
    kind: kind ?? this.kind,
    period: period ?? this.period,
    filter: filter ?? this.filter,
    choices: choices ?? this.choices,
    document: document ?? this.document,
    exportStatus: exportStatus ?? this.exportStatus,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    kind,
    period,
    filter,
    choices,
    document,
    exportStatus,
    message,
  ];
}

/// Builds one report at a time and exports it.
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  /// Creates the bloc.
  ReportBloc({
    required BuildReport buildReport,
    required ExportReportCsv exportReport,
    required ReportFilterOptions options,
    required Clock clock,
  }) : _build = buildReport,
       _export = exportReport,
       _options = options,
       _clock = clock,
       super(const ReportState()) {
    on<ReportStarted>(_onStarted, transformer: sequentialTransformer());
    on<ReportPeriodChanged>(
      _onPeriodChanged,
      transformer: sequentialTransformer(),
    );
    on<ReportFilterChanged>(
      _onFilterChanged,
      transformer: sequentialTransformer(),
    );
    on<ReportRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<ReportExportRequested>(_onExport, transformer: sequentialTransformer());
  }

  final BuildReport _build;
  final ExportReportCsv _export;
  final ReportFilterOptions _options;
  final Clock _clock;

  Future<void> _onStarted(
    ReportStarted event,
    Emitter<ReportState> emit,
  ) async {
    final kind = event.kind;
    final range = ReportPeriod.thisMonth.rangeFor(_clock.now())!;
    emit(
      ReportState(
        status: ViewStatus.loading,
        kind: kind,
        filter: ReportFilter(range: range),
      ),
    );
    final wantsChoices =
        kind.supportsProduct || kind.supportsCustomer || kind.supportsSupplier;
    if (wantsChoices) {
      final choices = await _options.load();
      if (isClosed) {
        return;
      }
      final loaded = choices.valueOrNull;
      if (loaded != null) {
        emit(state.copyWith(choices: loaded));
      }
    }
    await _load(emit);
  }

  Future<void> _onPeriodChanged(
    ReportPeriodChanged event,
    Emitter<ReportState> emit,
  ) async {
    final current = state.filter;
    if (current == null) {
      return;
    }
    final range = event.period == ReportPeriod.custom
        ? event.range
        : event.period.rangeFor(_clock.now());
    if (range == null) {
      return;
    }
    emit(
      state.copyWith(
        period: event.period,
        filter: current.copyWith(range: range),
      ),
    );
    await _load(emit);
  }

  Future<void> _onFilterChanged(
    ReportFilterChanged event,
    Emitter<ReportState> emit,
  ) async {
    emit(state.copyWith(filter: event.filter));
    await _load(emit);
  }

  Future<void> _load(Emitter<ReportState> emit) async {
    final kind = state.kind;
    final filter = state.filter;
    if (kind == null || filter == null) {
      return;
    }
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _build(kind, filter);
    if (isClosed) {
      return;
    }
    result.when(
      success: (document) => emit(
        state.copyWith(
          status: document.hasRows ? ViewStatus.loaded : ViewStatus.empty,
          document: document,
        ),
      ),
      failure: (failure) => emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }

  Future<void> _onExport(
    ReportExportRequested event,
    Emitter<ReportState> emit,
  ) async {
    final document = state.document;
    if (document == null || state.exportStatus == SubmitStatus.submitting) {
      return;
    }
    emit(state.copyWith(exportStatus: SubmitStatus.submitting));
    final result = await _export(document);
    if (isClosed) {
      return;
    }
    result.when(
      success: (_) => emit(state.copyWith(exportStatus: SubmitStatus.success)),
      failure: (failure) => emit(
        state.copyWith(
          exportStatus: SubmitStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }
}
