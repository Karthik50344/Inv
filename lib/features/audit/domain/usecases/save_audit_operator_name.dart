import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_operator_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Sets who is named on audit events made on this device.
///
/// Inventrix has no sign-in, so this is only a label the business types;
/// the change itself is recorded (with the old and new name) and the screens
/// say the name is not verified.
final class SaveAuditOperatorName {
  /// Creates the use case.
  const SaveAuditOperatorName({
    required AuditOperatorRepository repository,
    required TransactionRunner transactions,
    required AuditLogRepository audit,
    required Clock clock,
    required IdGenerator ids,
  }) : _repository = repository,
       _transactions = transactions,
       _audit = audit,
       _clock = clock,
       _ids = ids;

  final AuditOperatorRepository _repository;
  final TransactionRunner _transactions;
  final AuditLogRepository _audit;
  final Clock _clock;
  final IdGenerator _ids;

  /// Saves [text] (trimmed; empty clears the name).
  Future<Result<void>> call(String text) async {
    final next = text.trim().isEmpty ? null : text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (next != null && next.length > 40) {
      return const Result.failure(
        ValidationFailure(
          'Use at most 40 characters.',
          fieldErrors: {'name': 'Use at most 40 characters.'},
        ),
      );
    }
    final current = await _repository.name();
    if (current.isFailure) {
      return Result.failure(current.failureOrNull!);
    }
    if (current.valueOrNull == next) {
      return const Result.success(null);
    }
    final now = _clock.now();
    return _transactions.runResult<void>(() async {
      (await _repository.save(next, now)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'settings',
          entityId: 'audit_operator',
          action: 'operator_changed',
          summary: next == null ? 'Operator name cleared.' : 'Operator name set to "$next".',
          occurredAt: now,
          previousValues: {'name': current.valueOrNull},
          newValues: {'name': next},
        ),
      )).getOrThrow();
    });
  }
}
