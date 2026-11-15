import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/payments/domain/entities/invoice_settlement_view.dart';
import 'package:inventrix/features/payments/domain/entities/party_balance.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the balance card on a customer or supplier screen.
final class PartyBalanceState extends Equatable {
  /// Creates a state.
  const PartyBalanceState({
    this.status = ViewStatus.initial,
    this.balance,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// The party's balance once loaded.
  final PartyBalance? balance;

  /// Error message for the user.
  final String? message;

  @override
  List<Object?> get props => [status, balance, message];
}

/// Loads the balance of one customer or supplier.
class PartyBalanceCubit extends Cubit<PartyBalanceState> {
  /// Creates the cubit.
  PartyBalanceCubit({required GetPartyBalance getBalance})
    : _getBalance = getBalance,
      super(const PartyBalanceState());

  final GetPartyBalance _getBalance;

  /// Loads (or reloads) the balance.
  Future<void> load(PartyType type, String partyId) async {
    emit(const PartyBalanceState(status: ViewStatus.loading));
    final result = await _getBalance(type, partyId);
    if (isClosed) {
      return;
    }
    result.when(
      success: (balance) => emit(
        PartyBalanceState(status: ViewStatus.loaded, balance: balance),
      ),
      failure: (failure) => emit(
        PartyBalanceState(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }
}

/// State of the outstanding-balances screen.
final class OutstandingState extends Equatable {
  /// Creates a state.
  const OutstandingState({
    this.type = PartyType.customer,
    this.status = ViewStatus.initial,
    this.balances = const [],
    this.total,
    this.message,
  });

  /// Which side is shown.
  final PartyType type;

  /// Loading status.
  final ViewStatus status;

  /// Parties with a non-zero balance, largest first.
  final List<PartyBalance> balances;

  /// Sum of the positive balances (what is owed), if any.
  final Money? total;

  /// Error message for the user.
  final String? message;

  @override
  List<Object?> get props => [type, status, balances, total, message];
}

/// Lists who owes us money and whom we owe.
class OutstandingCubit extends Cubit<OutstandingState> {
  /// Creates the cubit.
  OutstandingCubit({required GetPartyBalance getBalance})
    : _getBalance = getBalance,
      super(const OutstandingState());

  final GetPartyBalance _getBalance;

  /// Loads the list for [type].
  Future<void> load([PartyType? type]) async {
    final selected = type ?? state.type;
    emit(OutstandingState(type: selected, status: ViewStatus.loading));
    final result = await _getBalance.outstanding(selected);
    if (isClosed) {
      return;
    }
    result.when(
      success: (list) {
        Money? total;
        for (final b in list.where((b) => b.balance.isPositive)) {
          total = total == null ? b.balance : total + b.balance;
        }
        emit(
          OutstandingState(
            type: selected,
            status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
            balances: list,
            total: total,
          ),
        );
      },
      failure: (failure) => emit(
        OutstandingState(
          type: selected,
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }
}

/// State of the payment-status card on an invoice screen.
final class InvoiceSettlementState extends Equatable {
  /// Creates a state.
  const InvoiceSettlementState({
    this.status = ViewStatus.initial,
    this.view,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// The invoice settlement once loaded.
  final InvoiceSettlementView? view;

  /// Error message for the user.
  final String? message;

  @override
  List<Object?> get props => [status, view, message];
}

/// Loads the payment status of one invoice.
class InvoiceSettlementCubit extends Cubit<InvoiceSettlementState> {
  /// Creates the cubit.
  InvoiceSettlementCubit({required GetOpenInvoices openInvoices})
    : _open = openInvoices,
      super(const InvoiceSettlementState());

  final GetOpenInvoices _open;

  /// Loads (or reloads) the settlement.
  Future<void> load(InvoiceKind kind, String invoiceId) async {
    emit(const InvoiceSettlementState(status: ViewStatus.loading));
    final result = await _open.settlementOf(kind, invoiceId);
    if (isClosed) {
      return;
    }
    result.when(
      success: (view) => emit(
        InvoiceSettlementState(status: ViewStatus.loaded, view: view),
      ),
      failure: (failure) => emit(
        InvoiceSettlementState(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }
}
