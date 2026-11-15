import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/returns/domain/entities/return_filter.dart';
import 'package:inventrix/features/returns/domain/entities/return_summary.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Events of the return list.
sealed class ReturnsEvent extends Equatable {
  const ReturnsEvent();

  @override
  List<Object?> get props => [];
}

/// Load the list for the first time.
final class ReturnsStarted extends ReturnsEvent {
  /// Creates the event.
  const ReturnsStarted();
}

/// Reload with the current filter.
final class ReturnsRefreshed extends ReturnsEvent {
  /// Creates the event.
  const ReturnsRefreshed();
}

/// The search text changed.
final class ReturnsSearchChanged extends ReturnsEvent {
  /// Creates the event.
  const ReturnsSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// The kind filter changed (`null` shows both).
final class ReturnsKindChanged extends ReturnsEvent {
  /// Creates the event.
  const ReturnsKindChanged(this.kind);

  /// Sales, purchase or both.
  final InvoiceKind? kind;

  @override
  List<Object?> get props => [kind];
}

/// State of the return list.
final class ReturnsState extends Equatable {
  /// Creates a state.
  const ReturnsState({
    this.status = ViewStatus.initial,
    this.items = const [],
    this.filter = const ReturnFilter(),
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded returns.
  final List<ReturnSummary> items;

  /// Active filter.
  final ReturnFilter filter;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  ReturnsState copyWith({
    ViewStatus? status,
    List<ReturnSummary>? items,
    ReturnFilter? filter,
    String? message,
  }) => ReturnsState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    message: message,
  );

  @override
  List<Object?> get props => [status, items, filter, message];
}

/// Lists returns with search and a sales/purchase filter.
class ReturnsBloc extends Bloc<ReturnsEvent, ReturnsState> {
  /// Creates the bloc.
  ReturnsBloc({required ReturnRepository returns})
    : _returns = returns,
      super(const ReturnsState()) {
    on<ReturnsStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<ReturnsRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<ReturnsSearchChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(query: event.query)));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<ReturnsKindChanged>((event, emit) {
      emit(
        state.copyWith(
          filter: event.kind == null
              ? state.filter.copyWith(clearKind: true)
              : state.filter.copyWith(kind: event.kind),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
  }

  final ReturnRepository _returns;

  Future<void> _load(Emitter<ReturnsState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _returns.search(state.filter);
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final list = result.valueOrNull!;
    emit(
      state.copyWith(
        status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        items: list,
      ),
    );
  }
}
