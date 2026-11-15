import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/return_filter.dart';
import 'package:inventrix/features/returns/domain/entities/return_summary.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Persistence contract for sales and purchase returns.
///
/// Returns are append-only: there is no update or delete. [insert] must be
/// called inside `TransactionRunner.runResult` together with the stock
/// movements and the audit entry.
abstract interface class ReturnRepository {
  /// Lists returns matching [filter], newest first.
  Future<Result<List<ReturnSummary>>> search(ReturnFilter filter);

  /// Loads one return with its lines; `NotFoundFailure` if missing.
  Future<Result<ReturnDocument>> getById(InvoiceKind kind, String id);

  /// The return recorded with [key], if any (for idempotent posting).
  Future<Result<ReturnDocument?>> findByIdempotencyKey(
    InvoiceKind kind,
    String key,
  );

  /// Every return against one invoice, oldest first.
  Future<Result<List<ReturnDocument>>> forInvoice(
    InvoiceKind kind,
    String invoiceId,
  );

  /// Inserts the return and its lines.
  Future<Result<void>> insert(ReturnDocument document);
}
