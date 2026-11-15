import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_filter.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_summary.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Persistence contract for purchase invoices.
///
/// Methods that change several rows or must be atomic with stock changes are
/// called inside `TransactionRunner.runResult` by the use cases.
abstract interface class PurchaseRepository {
  /// Lists invoices matching [filter], newest invoice date first.
  Future<Result<List<PurchaseSummary>>> search(PurchaseFilter filter);

  /// Loads one invoice with its lines; `NotFoundFailure` if missing.
  Future<Result<PurchaseInvoice>> getById(String id);

  /// Inserts a new draft, or replaces the header and lines of an existing
  /// draft. Fails with `ValidationFailure` when the stored invoice is not a
  /// draft.
  Future<Result<void>> saveDraft(PurchaseInvoice invoice);

  /// Moves invoice [id] from one of [from] to [to] (not for posting or
  /// voiding). Fails with `ValidationFailure` if its status is no longer one
  /// of [from], so a stale screen cannot overwrite a newer state.
  Future<Result<void>> changeStatus(
    String id, {
    required Set<DocumentStatus> from,
    required DocumentStatus to,
    required DateTime at,
  });

  /// Marks the invoice posted with its [number]. Only drafts and approved
  /// invoices can be posted; anything else fails with `ValidationFailure`
  /// (this is what prevents double posting).
  Future<Result<void>> markPosted(
    String id, {
    required String number,
    required DateTime at,
  });

  /// Marks a posted invoice as voided. Fails with `ValidationFailure` if it
  /// is not posted.
  Future<Result<void>> markVoided(
    String id, {
    required String reason,
    required DateTime at,
  });

  /// Total of the supplier's posted invoices.
  Future<Result<Money>> postedTotalForSupplier(String supplierId);
}
