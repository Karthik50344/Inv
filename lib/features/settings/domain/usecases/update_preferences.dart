import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Applies a change to the preferences atomically.
///
/// Turning an approval step on or off is audited because it changes who may
/// post documents; display preferences are not.
final class UpdatePreferences {
  /// Creates the use case.
  const UpdatePreferences({
    required PreferencesRepository repository,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PreferencesRepository _repository;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Reads the stored preferences, applies [change], validates and saves.
  Future<Result<AppPreferences>> call(
    AppPreferences Function(AppPreferences current) change,
  ) => _transactions.runResult(() async {
    final current = (await _repository.load()).getOrThrow();
    final updated = change(current);
    if (!AppPreferences.reminderChoices.contains(updated.backupReminderDays)) {
      throw const FailureException(
        ValidationFailure('Choose Off, 7, 14 or 30 days.'),
      );
    }
    if (updated == current) {
      return current;
    }
    (await _repository.save(updated)).getOrThrow();
    await _auditApproval(
      'purchase_approval',
      'Purchase approval',
      current.purchaseApprovalRequired,
      updated.purchaseApprovalRequired,
    );
    await _auditApproval(
      'sales_approval',
      'Sales approval',
      current.salesApprovalRequired,
      updated.salesApprovalRequired,
    );
    return updated;
  });

  Future<void> _auditApproval(
    String id,
    String label,
    bool before,
    bool after,
  ) async {
    if (before == after) {
      return;
    }
    (await _audit.record(
      AuditEntry(
        id: _ids.newId(),
        entityType: 'settings',
        entityId: id,
        action: after ? 'enabled' : 'disabled',
        summary: '$label ${after ? 'turned on' : 'turned off'}.',
        occurredAt: _clock.now(),
      ),
    )).getOrThrow();
  }
}
