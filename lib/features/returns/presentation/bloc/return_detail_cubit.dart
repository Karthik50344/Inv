import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// State of the return detail screen.
final class ReturnDetailState extends Equatable {
  /// Creates a state.
  const ReturnDetailState({
    this.status = DetailStatus.loading,
    this.document,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The return.
  final ReturnDocument? document;

  /// Error message, if any.
  final String? message;

  @override
  List<Object?> get props => [status, document, message];
}

/// Loads one return.
class ReturnDetailCubit extends Cubit<ReturnDetailState> {
  /// Creates the cubit.
  ReturnDetailCubit({required ReturnRepository returns})
    : _returns = returns,
      super(const ReturnDetailState());

  final ReturnRepository _returns;

  /// Loads return [id] of [kind]; unknown ids end in
  /// [DetailStatus.notFound].
  Future<void> load(InvoiceKind kind, String id) async {
    emit(const ReturnDetailState());
    final result = await _returns.getById(kind, id);
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(
        ReturnDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    emit(
      ReturnDetailState(
        status: DetailStatus.loaded,
        document: result.valueOrNull,
      ),
    );
  }
}

/// State of the "returns of this invoice" card.
final class InvoiceReturnsState extends Equatable {
  /// Creates a state.
  const InvoiceReturnsState({
    this.status = DetailStatus.loading,
    this.returns = const [],
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// Returns posted against the invoice, oldest first.
  final List<ReturnDocument> returns;

  /// Error message, if any.
  final String? message;

  /// Total value returned, or `null` when there are no returns.
  Money? get returnedTotal {
    if (returns.isEmpty) {
      return null;
    }
    final first = returns.first.total;
    return Money.sum(
      returns.map((r) => r.total),
      currencyCode: first.currencyCode,
      decimalPlaces: first.decimalPlaces,
    );
  }

  @override
  List<Object?> get props => [status, returns, message];
}

/// Loads the returns of one invoice for its detail screen.
class InvoiceReturnsCubit extends Cubit<InvoiceReturnsState> {
  /// Creates the cubit.
  InvoiceReturnsCubit({required ReturnRepository returns})
    : _returns = returns,
      super(const InvoiceReturnsState());

  final ReturnRepository _returns;

  /// Loads the returns of invoice [invoiceId].
  Future<void> load(InvoiceKind kind, String invoiceId) async {
    emit(const InvoiceReturnsState());
    final result = await _returns.forInvoice(kind, invoiceId);
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    emit(
      failure != null
          ? InvoiceReturnsState(
              status: DetailStatus.failure,
              message: failure.userMessage,
            )
          : InvoiceReturnsState(
              status: DetailStatus.loaded,
              returns: result.valueOrNull!,
            ),
    );
  }
}
