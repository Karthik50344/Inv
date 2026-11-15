import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/sales/domain/entities/sales_filter.dart';
import 'package:inventrix/features/sales/domain/entities/sales_summary.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_event.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the sale list.
final class SalesState extends Equatable {
  /// Creates a state.
  const SalesState({
    this.status = ViewStatus.initial,
    this.items = const [],
    this.filter = const SalesFilter(),
    this.approvalRequired = false,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded invoices.
  final List<SalesSummary> items;

  /// Active filter.
  final SalesFilter filter;

  /// Whether sales need approval before posting.
  final bool approvalRequired;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  SalesState copyWith({
    ViewStatus? status,
    List<SalesSummary>? items,
    SalesFilter? filter,
    bool? approvalRequired,
    String? message,
  }) => SalesState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    approvalRequired: approvalRequired ?? this.approvalRequired,
    message: message,
  );

  @override
  List<Object?> get props => [status, items, filter, approvalRequired, message];
}

/// Lists sale invoices with search and status filtering.
class SalesBloc extends Bloc<SalesEvent, SalesState> {
  /// Creates the bloc.
  SalesBloc({
    required SalesRepository sales,
    required SettingsRepository settings,
  }) : _sales = sales,
       _settings = settings,
       super(const SalesState()) {
    on<SalesStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<SalesRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<SalesSearchChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(query: event.query)));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<SalesStatusChanged>((event, emit) {
      emit(
        state.copyWith(
          filter: event.status == null
              ? state.filter.copyWith(clearStatus: true)
              : state.filter.copyWith(status: event.status),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<SalesApprovalToggled>((event, emit) async {
      final result = await _settings.setSalesApprovalRequired(
        event.required,
      );
      final failure = result.failureOrNull;
      if (failure != null) {
        emit(state.copyWith(message: failure.userMessage));
        return;
      }
      emit(state.copyWith(approvalRequired: event.required));
    }, transformer: sequentialTransformer());
  }

  final SalesRepository _sales;
  final SettingsRepository _settings;

  Future<void> _load(Emitter<SalesState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final items = await _sales.search(state.filter);
    final approval = await _settings.isSalesApprovalRequired();
    final failure = items.failureOrNull ?? approval.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final list = items.valueOrNull!;
    emit(
      state.copyWith(
        status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        items: list,
        approvalRequired: approval.valueOrNull,
      ),
    );
  }
}
