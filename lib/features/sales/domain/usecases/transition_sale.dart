import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Workflow steps that do not touch inventory.
enum SaleAction {
  /// Draft -> pending approval (only when approval is enabled).
  submit(DocumentStatus.pendingApproval, 'submitted for approval'),

  /// Pending approval -> approved.
  approve(DocumentStatus.approved, 'approved'),

  /// Pending approval -> draft (send back for changes).
  reopen(DocumentStatus.draft, 'returned to draft'),

  /// Not yet posted -> cancelled.
  cancel(DocumentStatus.cancelled, 'cancelled');

  const SaleAction(this.target, this.auditText);

  /// Status the action leads to.
  final DocumentStatus target;

  /// Text for the audit trail.
  final String auditText;
}

/// Moves a sale through the approval workflow or cancels it before
/// posting. Posting and voiding have their own use cases because they change
/// inventory.
final class TransitionSale {
  /// Creates the use case.
  const TransitionSale({
    required SalesRepository sales,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _sales = sales,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final SalesRepository _sales;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Applies [action] to sale [id]. The status is re-read inside the
  /// transaction, so a stale screen cannot skip a workflow step.
  Future<Result<SalesInvoice>> call(
    String id,
    SaleAction action,
  ) => _transactions.runResult(() async {
    final invoice = (await _sales.getById(id)).getOrThrow();
    final target = action.target;
    if (!invoice.status.canTransitionTo(target)) {
      throw FailureException(
        ValidationFailure(
          'A ${invoice.status.label.toLowerCase()} sale cannot be '
          '${action.auditText}.',
        ),
      );
    }
    if (action == SaleAction.submit) {
      final required = (await _settings.isSalesApprovalRequired()).getOrThrow();
      if (!required) {
        throw const FailureException(
          ValidationFailure(
            'Approval is not enabled. Post the sale directly.',
          ),
        );
      }
    }
    final now = _clock.now();
    (await _sales.changeStatus(
      id,
      from: {invoice.status},
      to: target,
      at: now,
    )).getOrThrow();
    (await _audit.record(
      AuditEntry(
        id: _ids.newId(),
        entityType: SalesNumbering.sourceType,
        entityId: id,
        action: action.name,
        summary: 'Sales invoice ${invoice.displayNumber} ${action.auditText}',
        occurredAt: now,
      ),
    )).getOrThrow();
    return (await _sales.getById(id)).getOrThrow();
  });
}
