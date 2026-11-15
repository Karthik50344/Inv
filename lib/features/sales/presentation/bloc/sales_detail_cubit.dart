import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/usecases/post_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/share_invoice_pdf.dart';
import 'package:inventrix/features/sales/domain/usecases/transition_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/void_sale.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';

/// State of the sale detail screen.
final class SalesDetailState extends Equatable {
  /// Creates a state.
  const SalesDetailState({
    this.status = DetailStatus.loading,
    this.invoice,
    this.approvalRequired = false,
    this.busy = false,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The invoice.
  final SalesInvoice? invoice;

  /// Whether sales need approval before posting.
  final bool approvalRequired;

  /// Whether a workflow action is running.
  final bool busy;

  /// One-shot user-facing message (result of the last action).
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  SalesDetailState copyWith({
    DetailStatus? status,
    SalesInvoice? invoice,
    bool? approvalRequired,
    bool? busy,
    String? message,
  }) => SalesDetailState(
    status: status ?? this.status,
    invoice: invoice ?? this.invoice,
    approvalRequired: approvalRequired ?? this.approvalRequired,
    busy: busy ?? this.busy,
    message: message,
  );

  @override
  List<Object?> get props => [status, invoice, approvalRequired, busy, message];
}

/// Loads one sale and runs its workflow actions.
class SalesDetailCubit extends Cubit<SalesDetailState> {
  /// Creates the cubit.
  SalesDetailCubit({
    required SalesRepository sales,
    required SettingsRepository settings,
    required TransitionSale transition,
    required PostSale post,
    required VoidSale voidSale,
    required ShareInvoicePdf shareInvoice,
  }) : _sales = sales,
       _settings = settings,
       _transition = transition,
       _post = post,
       _void = voidSale,
       _share = shareInvoice,
       super(const SalesDetailState());

  final SalesRepository _sales;
  final SettingsRepository _settings;
  final TransitionSale _transition;
  final PostSale _post;
  final VoidSale _void;
  final ShareInvoicePdf _share;
  String? _id;

  /// Loads sale [id]; unknown ids end in [DetailStatus.notFound].
  Future<void> load(String id) async {
    _id = id;
    emit(const SalesDetailState());
    final invoice = await _sales.getById(id);
    final approval = await _settings.isSalesApprovalRequired();
    if (isClosed) {
      return;
    }
    final failure = invoice.failureOrNull ?? approval.failureOrNull;
    if (failure != null) {
      emit(
        SalesDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    emit(
      SalesDetailState(
        status: DetailStatus.loaded,
        invoice: invoice.valueOrNull,
        approvalRequired: approval.valueOrNull ?? false,
      ),
    );
  }

  /// Submits the draft for approval.
  Future<void> submit() => _run(
    () => _transition(_requireId, SaleAction.submit),
    'Submitted for approval',
  );

  /// Approves a pending sale.
  Future<void> approve() =>
      _run(() => _transition(_requireId, SaleAction.approve), 'Approved');

  /// Sends a pending sale back to draft.
  Future<void> reopen() => _run(
    () => _transition(_requireId, SaleAction.reopen),
    'Returned to draft',
  );

  /// Cancels a sale that was never posted.
  Future<void> cancel() =>
      _run(() => _transition(_requireId, SaleAction.cancel), 'Cancelled');

  /// Posts the sale, adding its lines to stock.
  Future<void> post() =>
      _run(() => _post(_requireId), 'Posted. Stock has been reduced');

  /// Voids the posted sale, reversing its stock.
  Future<void> voidSale(String reason) => _run(
    () => _void(_requireId, reason: reason),
    'Voided. Stock has been put back',
  );

  /// Shares the invoice as a PDF through the system share sheet. Only a
  /// failure is reported; the share sheet is the confirmation.
  Future<void> sharePdf() async {
    if (_id == null || state.busy) {
      return;
    }
    emit(state.copyWith(busy: true));
    final result = await _share(_requireId);
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        busy: false,
        message: result.failureOrNull?.userMessage,
      ),
    );
  }

  String get _requireId => _id!;

  Future<void> _run(
    Future<Result<SalesInvoice>> Function() action,
    String successMessage,
  ) async {
    if (_id == null || state.busy) {
      return;
    }
    emit(state.copyWith(busy: true));
    final result = await action();
    if (isClosed) {
      return;
    }
    result.when(
      success: (invoice) => emit(
        state.copyWith(
          invoice: invoice,
          busy: false,
          message: '$successMessage.',
        ),
      ),
      failure: (failure) =>
          emit(state.copyWith(busy: false, message: failure.userMessage)),
    );
  }
}
