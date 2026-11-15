import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Workflow steps that do not touch inventory.
enum PurchaseAction {
  /// Draft -> pending approval (only when approval is enabled).
  submit(DocumentStatus.pendingApproval, 'submitted for approval'),

  /// Pending approval -> approved.
  approve(DocumentStatus.approved, 'approved'),

  /// Pending approval -> draft (send back for changes).
  reopen(DocumentStatus.draft, 'returned to draft'),

  /// Not yet posted -> cancelled.
  cancel(DocumentStatus.cancelled, 'cancelled');

  const PurchaseAction(this.target, this.auditText);

  /// Status the action leads to.
  final DocumentStatus target;

  /// Text for the audit trail.
  final String auditText;
}

/// Moves a purchase through the approval workflow or cancels it before
/// posting. Posting and voiding have their own use cases because they change
/// inventory.
final class TransitionPurchase {
  /// Creates the use case.
  const TransitionPurchase({
    required PurchaseRepository purchases,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _purchases = purchases,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PurchaseRepository _purchases;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Applies [action] to purchase [id]. The status is re-read inside the
  /// transaction, so a stale screen cannot skip a workflow step.
  Future<Result<PurchaseInvoice>> call(String id, PurchaseAction action) =>
      _transactions.runResult(() async {
        final invoice = (await _purchases.getById(id)).getOrThrow();
        final target = action.target;
        if (!invoice.status.canTransitionTo(target)) {
          throw FailureException(
            ValidationFailure(
              'A ${invoice.status.label.toLowerCase()} purchase cannot be '
              '${action.auditText}.',
            ),
          );
        }
        if (action == PurchaseAction.submit) {
          final required = (await _settings.isPurchaseApprovalRequired())
              .getOrThrow();
          if (!required) {
            throw const FailureException(
              ValidationFailure(
                'Approval is not enabled. Post the purchase directly.',
              ),
            );
          }
        }
        final now = _clock.now();
        (await _purchases.changeStatus(
          id,
          from: {invoice.status},
          to: target,
          at: now,
        )).getOrThrow();
        (await _audit.record(
          AuditEntry(
            id: _ids.newId(),
            entityType: PurchaseNumbering.sourceType,
            entityId: id,
            action: action.name,
            summary: 'Purchase ${invoice.displayNumber} ${action.auditText}',
            occurredAt: now,
          ),
        )).getOrThrow();
        return (await _purchases.getById(id)).getOrThrow();
      });
}
