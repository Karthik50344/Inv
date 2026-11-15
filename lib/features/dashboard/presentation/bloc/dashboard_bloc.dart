import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:inventrix/features/dashboard/domain/usecases/get_dashboard.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the dashboard.
final class DashboardState extends Equatable {
  /// Creates a state.
  const DashboardState({
    this.status = ViewStatus.initial,
    this.period = ReportPeriod.thisMonth,
    this.range,
    this.snapshot,
    this.message,
  });

  /// Loading status. `empty` means nothing has been recorded yet.
  final ViewStatus status;

  /// Selected period.
  final ReportPeriod period;

  /// The days of the period (set once the first load starts).
  final DateRange? range;

  /// The loaded figures; kept while a reload is running.
  final DashboardSnapshot? snapshot;

  /// User-facing error message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  DashboardState copyWith({
    ViewStatus? status,
    ReportPeriod? period,
    DateRange? range,
    DashboardSnapshot? snapshot,
    String? message,
  }) => DashboardState(
    status: status ?? this.status,
    period: period ?? this.period,
    range: range ?? this.range,
    snapshot: snapshot ?? this.snapshot,
    message: message,
  );

  @override
  List<Object?> get props => [status, period, range, snapshot, message];
}

/// Loads the dashboard figures for the chosen period.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  /// Creates the bloc.
  DashboardBloc({required GetDashboard getDashboard, required Clock clock})
    : _getDashboard = getDashboard,
      _clock = clock,
      super(const DashboardState()) {
    on<DashboardStarted>(
      (event, emit) => _load(emit, state.period, state.range),
      transformer: sequentialTransformer(),
    );
    on<DashboardRefreshed>(
      (event, emit) => _load(emit, state.period, state.range),
      transformer: sequentialTransformer(),
    );
    on<DashboardPeriodChanged>((event, emit) {
      final range = event.period == ReportPeriod.custom
          ? event.range
          : event.period.rangeFor(_clock.now());
      if (range == null) {
        return Future<void>.value();
      }
      return _load(emit, event.period, range);
    }, transformer: sequentialTransformer());
  }

  final GetDashboard _getDashboard;
  final Clock _clock;

  Future<void> _load(
    Emitter<DashboardState> emit,
    ReportPeriod period,
    DateRange? current,
  ) async {
    // A preset is re-evaluated against today so a long-open app moves on
    // to the new day or month; a custom range stays as chosen.
    final range =
        (period == ReportPeriod.custom ? current : null) ??
        period.rangeFor(_clock.now())!;
    emit(
      state.copyWith(status: ViewStatus.loading, period: period, range: range),
    );
    final result = await _getDashboard(range);
    if (isClosed) {
      return;
    }
    result.when(
      success: (snapshot) => emit(
        state.copyWith(
          status: snapshot.isBlank ? ViewStatus.empty : ViewStatus.loaded,
          snapshot: snapshot,
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
}
