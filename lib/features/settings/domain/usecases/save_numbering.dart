import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/features/settings/domain/entities/numbering_settings.dart';
import 'package:inventrix/features/settings/domain/repositories/numbering_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';

/// Validates and saves document prefixes and the counter padding.
///
/// Numbers already issued are never rewritten: the prefix is read when a
/// document is posted. Counters keep running across a prefix change, so a
/// number is never reused.
final class SaveNumbering {
  /// Creates the use case.
  const SaveNumbering({
    required NumberingRepository repository,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final NumberingRepository _repository;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Saves [prefixes] (raw text per kind) and [padding].
  ///
  /// Field errors use the key `prefix.<sequenceKey>` and `padding`.
  Future<Result<NumberingSettings>> call({
    required Map<DocumentKind, String> prefixes,
    required int padding,
  }) async {
    final errors = FieldErrors();
    final cleaned = <DocumentKind, String>{};
    final seen = <String, DocumentKind>{};
    for (final kind in DocumentKind.values) {
      final prefix = (prefixes[kind] ?? kind.defaultPrefix).trim();
      cleaned[kind] = prefix;
      final field = 'prefix.${kind.sequenceKey}';
      final problem = DocumentNumber.validatePrefix(prefix);
      if (problem != null) {
        errors.add(field, problem);
        continue;
      }
      final clash = seen[prefix.toUpperCase()];
      if (clash != null) {
        errors.add(
          field,
          'Already used for ${clash.label.toLowerCase()}. '
          'Give every document type its own prefix.',
        );
      } else {
        seen[prefix.toUpperCase()] = kind;
      }
    }
    errors.add('padding', DocumentNumber.validatePadding(padding));
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    return _transactions.runResult(() async {
      final current = (await _repository.load()).getOrThrow();
      final updated = NumberingSettings(
        prefixes: cleaned,
        padding: padding,
        lastValues: current.lastValues,
      );
      final changed = [
        for (final kind in DocumentKind.values)
          if (current.prefixOf(kind) != updated.prefixOf(kind)) kind,
      ];
      if (changed.isEmpty && current.padding == padding) {
        return current;
      }
      (await _repository.save(updated)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'settings',
          entityId: 'numbering',
          action: 'updated',
          summary: [
            for (final kind in changed)
              '${kind.label}: ${current.prefixOf(kind)} -> '
                  '${updated.prefixOf(kind)}',
            if (current.padding != padding)
              'Digits: ${current.padding} -> $padding',
          ].join('; '),
          occurredAt: _clock.now(),
        ),
      )).getOrThrow();
      return updated;
    });
  }
}

/// Moves a document counter forward, e.g. to continue from a paper book.
final class SetNextDocumentNumber {
  /// Creates the use case.
  const SetNextDocumentNumber({
    required NumberingRepository repository,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  /// Largest number that can be entered.
  static const int maxNumber = 999999999;

  final NumberingRepository _repository;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Makes [nextNumberText] the number of the next document of [kind].
  Future<Result<NumberingSettings>> call(
    DocumentKind kind,
    String nextNumberText,
  ) async {
    final wanted = int.tryParse(nextNumberText.trim());
    if (wanted == null || wanted < 1 || wanted > maxNumber) {
      return Result.failure(
        ValidationFailure(
          'Enter a whole number between 1 and $maxNumber.',
          fieldErrors: {
            'next.${kind.sequenceKey}':
                'Enter a whole number between 1 and $maxNumber.',
          },
        ),
      );
    }
    return _transactions.runResult(() async {
      final current = (await _repository.load()).getOrThrow();
      final next = current.nextValueOf(kind);
      if (wanted < next) {
        final message =
            'Numbers up to ${current.lastValueOf(kind)} are already used. '
            'Enter $next or higher.';
        throw FailureException(
          ValidationFailure(
            message,
            fieldErrors: {'next.${kind.sequenceKey}': message},
          ),
        );
      }
      if (wanted == next) {
        return current;
      }
      (await _repository.advanceTo(kind, wanted)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'settings',
          entityId: 'numbering',
          action: 'counter_advanced',
          summary: 'Next ${kind.label.toLowerCase()} number set to $wanted.',
          occurredAt: _clock.now(),
        ),
      )).getOrThrow();
      return (await _repository.load()).getOrThrow();
    });
  }
}
