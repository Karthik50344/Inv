import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile_input.dart';
import 'package:inventrix/features/settings/domain/repositories/business_profile_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Validates and saves the business identity printed on documents.
///
/// Posted documents are not touched: they keep the customer, prices and
/// totals they were posted with, and the profile is read when a document is
/// printed.
final class SaveBusinessProfile {
  /// Creates the use case.
  const SaveBusinessProfile({
    required BusinessProfileRepository repository,
    required LogoStorage logos,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _logos = logos,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final BusinessProfileRepository _repository;
  final LogoStorage _logos;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Validates [input] and saves it.
  Future<Result<BusinessProfile>> call(BusinessProfileInput input) async {
    final errors = FieldErrors()
      ..add(
        'name',
        Validators.requiredText(
          input.name,
          label: 'Business name',
          maxLength: 80,
        ),
      )
      ..add(
        'address',
        Validators.optionalText(
          input.address,
          label: 'Address',
          maxLength: 300,
        ),
      )
      ..add('phone', Validators.optionalPhone(input.phone))
      ..add('email', Validators.optionalEmail(input.email))
      ..add(
        'taxId',
        Validators.optionalText(
          input.taxId,
          label: 'Tax registration number',
          maxLength: 30,
        ),
      );
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final profile = BusinessProfile(
      name: input.name.trim(),
      address: blankToNull(input.address),
      phone: blankToNull(input.phone),
      email: blankToNull(input.email),
      taxId: blankToNull(input.taxId),
      logoPath: input.logoPath,
    );
    String? previousLogo;
    final saved = await _transactions.runResult(() async {
      final previous = (await _repository.find()).getOrThrow();
      previousLogo = previous?.logoPath;
      final changedFields = <String>[
        if (previous?.name != profile.name) 'name',
        if (previous?.address != profile.address) 'address',
        if (previous?.phone != profile.phone) 'phone',
        if (previous?.email != profile.email) 'email',
        if (previous?.taxId != profile.taxId) 'taxId',
        if (previous?.logoPath != profile.logoPath) 'logo',
      ];
      (await _repository.save(profile)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'settings',
          entityId: 'business_profile',
          action: 'updated',
          summary: 'Business profile updated.',
          occurredAt: _clock.now(),
          // Field names only: contact details stay out of the audit log.
          metadata: {'changedFields': changedFields},
        ),
      )).getOrThrow();
      return profile;
    });
    // Only after the commit: a replaced logo file is no longer referenced.
    final old = previousLogo;
    if (saved.isSuccess && old != null && old != profile.logoPath) {
      await _logos.delete(old);
    }
    return saved;
  }
}
