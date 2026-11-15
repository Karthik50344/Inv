import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/transition_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/void_purchase.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';

/// State of the purchase detail screen.
final class PurchaseDetailState extends Equatable {
  /// Creates a state.
  const PurchaseDetailState({
    this.status = DetailStatus.loading,
    this.invoice,
    this.approvalRequired = false,
    this.busy = false,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The invoice.
  final PurchaseInvoice? invoice;

  /// Whether purchases need approval before posting.
  final bool approvalRequired;

  /// Whether a workflow action is running.
  final bool busy;

  /// One-shot user-facing message (result of the last action).
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  PurchaseDetailState copyWith({
    DetailStatus? status,
    PurchaseInvoice? invoice,
    bool? approvalRequired,
    bool? busy,
    String? message,
  }) => PurchaseDetailState(
    status: status ?? this.status,
    invoice: invoice ?? this.invoice,
    approvalRequired: approvalRequired ?? this.approvalRequired,
    busy: busy ?? this.busy,
    message: message,
  );

  @override
  List<Object?> get props => [status, invoice, approvalRequired, busy, message];
}

/// Loads one purchase and runs its workflow actions.
class PurchaseDetailCubit extends Cubit<PurchaseDetailState> {
  /// Creates the cubit.
  PurchaseDetailCubit({
    required PurchaseRepository purchases,
    required SettingsRepository settings,
    required TransitionPurchase transition,
    required PostPurchase post,
    required VoidPurchase voidPurchase,
  }) : _purchases = purchases,
       _settings = settings,
       _transition = transition,
       _post = post,
       _void = voidPurchase,
       super(const PurchaseDetailState());

  final PurchaseRepository _purchases;
  final SettingsRepository _settings;
  final TransitionPurchase _transition;
  final PostPurchase _post;
  final VoidPurchase _void;
  String? _id;

  /// Loads purchase [id]; unknown ids end in [DetailStatus.notFound].
  Future<void> load(String id) async {
    _id = id;
    emit(const PurchaseDetailState());
    final invoice = await _purchases.getById(id);
    final approval = await _settings.isPurchaseApprovalRequired();
    if (isClosed) {
      return;
    }
    final failure = invoice.failureOrNull ?? approval.failureOrNull;
    if (failure != null) {
      emit(
        PurchaseDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    emit(
      PurchaseDetailState(
        status: DetailStatus.loaded,
        invoice: invoice.valueOrNull,
        approvalRequired: approval.valueOrNull ?? false,
      ),
    );
  }

  /// Submits the draft for approval.
  Future<void> submit() => _run(
    () => _transition(_requireId, PurchaseAction.submit),
    'Submitted for approval',
  );

  /// Approves a pending purchase.
  Future<void> approve() =>
      _run(() => _transition(_requireId, PurchaseAction.approve), 'Approved');

  /// Sends a pending purchase back to draft.
  Future<void> reopen() => _run(
    () => _transition(_requireId, PurchaseAction.reopen),
    'Returned to draft',
  );

  /// Cancels a purchase that was never posted.
  Future<void> cancel() =>
      _run(() => _transition(_requireId, PurchaseAction.cancel), 'Cancelled');

  /// Posts the purchase, adding its lines to stock.
  Future<void> post() =>
      _run(() => _post(_requireId), 'Posted. Stock has been updated');

  /// Voids the posted purchase, reversing its stock.
  Future<void> voidPurchase(String reason) => _run(
    () => _void(_requireId, reason: reason),
    'Voided. Stock has been reversed',
  );

  String get _requireId => _id!;

  Future<void> _run(
    Future<Result<PurchaseInvoice>> Function() action,
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
