import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_filter.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_summary.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_event.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the purchase list.
final class PurchaseState extends Equatable {
  /// Creates a state.
  const PurchaseState({
    this.status = ViewStatus.initial,
    this.items = const [],
    this.filter = const PurchaseFilter(),
    this.approvalRequired = false,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded invoices.
  final List<PurchaseSummary> items;

  /// Active filter.
  final PurchaseFilter filter;

  /// Whether purchases need approval before posting.
  final bool approvalRequired;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  PurchaseState copyWith({
    ViewStatus? status,
    List<PurchaseSummary>? items,
    PurchaseFilter? filter,
    bool? approvalRequired,
    String? message,
  }) => PurchaseState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    approvalRequired: approvalRequired ?? this.approvalRequired,
    message: message,
  );

  @override
  List<Object?> get props => [status, items, filter, approvalRequired, message];
}

/// Lists purchase invoices with search and status filtering.
class PurchaseBloc extends Bloc<PurchaseEvent, PurchaseState> {
  /// Creates the bloc.
  PurchaseBloc({
    required PurchaseRepository purchases,
    required SettingsRepository settings,
  }) : _purchases = purchases,
       _settings = settings,
       super(const PurchaseState()) {
    on<PurchasesStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<PurchasesRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<PurchasesSearchChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(query: event.query)));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<PurchasesStatusChanged>((event, emit) {
      emit(
        state.copyWith(
          filter: event.status == null
              ? state.filter.copyWith(clearStatus: true)
              : state.filter.copyWith(status: event.status),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<PurchasesApprovalToggled>((event, emit) async {
      final result = await _settings.setPurchaseApprovalRequired(
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

  final PurchaseRepository _purchases;
  final SettingsRepository _settings;

  Future<void> _load(Emitter<PurchaseState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final items = await _purchases.search(state.filter);
    final approval = await _settings.isPurchaseApprovalRequired();
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
