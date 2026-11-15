import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_filter.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Events of the payment history screen.
sealed class PaymentsEvent extends Equatable {
  const PaymentsEvent();

  @override
  List<Object?> get props => [];
}

/// Load the history for the first time.
final class PaymentsStarted extends PaymentsEvent {
  /// Creates the event.
  const PaymentsStarted();
}

/// Reload with the current filter.
final class PaymentsRefreshed extends PaymentsEvent {
  /// Creates the event.
  const PaymentsRefreshed();
}

/// The search text changed.
final class PaymentsSearchChanged extends PaymentsEvent {
  /// Creates the event.
  const PaymentsSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// The customer/supplier filter changed (`null` = both).
final class PaymentsPartyTypeChanged extends PaymentsEvent {
  /// Creates the event.
  const PaymentsPartyTypeChanged(this.partyType);

  /// The party type to show.
  final PartyType? partyType;

  @override
  List<Object?> get props => [partyType];
}

/// The payment/refund filter changed (`null` = both).
final class PaymentsKindChanged extends PaymentsEvent {
  /// Creates the event.
  const PaymentsKindChanged(this.kind);

  /// The kind to show.
  final PaymentKind? kind;

  @override
  List<Object?> get props => [kind];
}

/// Reversed payments are shown or hidden.
final class PaymentsReversedToggled extends PaymentsEvent {
  /// Creates the event.
  const PaymentsReversedToggled({required this.show});

  /// Whether to include reversed payments.
  final bool show;

  @override
  List<Object?> get props => [show];
}

/// State of the payment history screen.
final class PaymentsState extends Equatable {
  /// Creates a state.
  const PaymentsState({
    this.status = ViewStatus.initial,
    this.items = const [],
    this.filter = const PaymentFilter(),
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Payments newest first.
  final List<Payment> items;

  /// Current filter.
  final PaymentFilter filter;

  /// Error message for the user.
  final String? message;

  /// A copy with changes.
  PaymentsState copyWith({
    ViewStatus? status,
    List<Payment>? items,
    PaymentFilter? filter,
    String? message,
  }) => PaymentsState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    message: message,
  );

  @override
  List<Object?> get props => [status, items, filter, message];
}

/// Loads and filters the payment history.
class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  /// Creates the bloc.
  PaymentsBloc({required PaymentRepository payments})
    : _payments = payments,
      super(const PaymentsState()) {
    on<PaymentsStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<PaymentsRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<PaymentsSearchChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(query: event.query)));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<PaymentsPartyTypeChanged>((event, emit) {
      final type = event.partyType;
      emit(
        state.copyWith(
          filter: type == null
              ? state.filter.copyWith(clearPartyType: true)
              : state.filter.copyWith(partyType: type),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<PaymentsKindChanged>((event, emit) {
      final kind = event.kind;
      emit(
        state.copyWith(
          filter: kind == null
              ? state.filter.copyWith(clearKind: true)
              : state.filter.copyWith(kind: kind),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<PaymentsReversedToggled>((event, emit) {
      emit(
        state.copyWith(
          filter: state.filter.copyWith(includeReversed: event.show),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
  }

  final PaymentRepository _payments;

  Future<void> _load(Emitter<PaymentsState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _payments.search(state.filter);
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
