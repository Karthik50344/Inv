import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_line.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_totals.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_line_builder.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Creates a purchase draft or replaces the content of an existing draft.
///
/// A draft never touches inventory. Validation and money arithmetic live
/// here (and in [PurchaseLineBuilder]), not in the UI.
final class SavePurchaseDraft {
  /// Creates the use case.
  const SavePurchaseDraft({
    required PurchaseRepository purchases,
    required SupplierRepository suppliers,
    required PurchaseLineBuilder lineBuilder,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _purchases = purchases,
       _suppliers = suppliers,
       _lineBuilder = lineBuilder,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PurchaseRepository _purchases;
  final SupplierRepository _suppliers;
  final PurchaseLineBuilder _lineBuilder;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Maximum number of lines on one invoice.
  static const int maxLines = 200;

  /// Validates [input] and saves the draft.
  ///
  /// Field errors use the keys `supplierId`, `invoiceDate`, `dueDate`,
  /// `supplierReference`, `notes`, `lines` and `lines.<index>.<field>`.
  Future<Result<PurchaseInvoice>> call(PurchaseDraftInput input) async {
    final currencyResult = await _settings.getCurrencyConfig();
    final currency = currencyResult.valueOrNull;
    if (currency == null) {
      return Result.failure(currencyResult.failureOrNull!);
    }

    final errors = FieldErrors();
    Supplier? supplier;
    if (input.supplierId.trim().isEmpty) {
      errors.add('supplierId', 'Choose a supplier.');
    } else {
      final found = await _suppliers.getById(input.supplierId);
      supplier = found.valueOrNull;
      final failure = found.failureOrNull;
      if (failure != null) {
        if (failure is! NotFoundFailure) {
          return Result.failure(failure);
        }
        errors.add('supplierId', 'This supplier no longer exists.');
      } else if (supplier!.isArchived) {
        errors.add(
          'supplierId',
          'This supplier is archived. Restore it before purchasing.',
        );
      }
    }

    final invoiceDate = input.invoiceDate == null
        ? null
        : _dateOnly(input.invoiceDate!);
    if (invoiceDate == null) {
      errors.add('invoiceDate', 'Invoice date is required.');
    }
    final dueDate = input.dueDate == null ? null : _dateOnly(input.dueDate!);
    if (dueDate != null &&
        invoiceDate != null &&
        dueDate.isBefore(invoiceDate)) {
      errors.add('dueDate', 'The due date cannot be before the invoice date.');
    }
    errors
      ..add(
        'supplierReference',
        Validators.optionalText(
          input.supplierReference,
          label: 'Supplier invoice no.',
          maxLength: 60,
        ),
      )
      ..add(
        'notes',
        Validators.optionalText(input.notes, label: 'Notes', maxLength: 500),
      );

    final lines = <PurchaseLine>[];
    if (input.lines.isEmpty) {
      errors.add('lines', 'Add at least one product.');
    } else if (input.lines.length > maxLines) {
      errors.add('lines', 'An invoice can have at most $maxLines lines.');
    } else {
      for (var i = 0; i < input.lines.length; i++) {
        final built = await _lineBuilder.build(
          input: input.lines[i],
          lineNo: i + 1,
          lineId: _ids.newId(),
          currency: currency,
        );
        final line = built.valueOrNull;
        if (line != null) {
          lines.add(line);
          continue;
        }
        final failure = built.failureOrNull!;
        if (failure is! ValidationFailure) {
          return Result.failure(failure);
        }
        failure.fieldErrors.forEach(
          (field, message) => errors.add('lines.$i.$field', message),
        );
      }
    }
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }

    final chosenSupplier = supplier!;
    final now = _clock.now();
    final id = input.id ?? _ids.newId();
    final totals = PurchaseTotals.fromLines(lines, zero: currency.zero());

    return _transactions.runResult(() async {
      var createdAt = now;
      final editing = input.id != null;
      if (editing) {
        final existing = (await _purchases.getById(id)).getOrThrow();
        if (!existing.isEditable) {
          throw const FailureException(
            ValidationFailure('Only draft purchases can be edited.'),
          );
        }
        final stored = existing.totals.total;
        if (stored.currencyCode != currency.currencyCode ||
            stored.decimalPlaces != currency.decimalPlaces) {
          throw const FailureException(
            ValidationFailure(
              'The currency changed after this draft was created. '
              'Create a new purchase instead.',
            ),
          );
        }
        createdAt = existing.createdAt;
      }
      final invoice = PurchaseInvoice(
        id: id,
        supplierId: chosenSupplier.id,
        supplierName: chosenSupplier.name,
        status: DocumentStatus.draft,
        invoiceDate: invoiceDate!,
        dueDate: dueDate,
        supplierReference: blankToNull(input.supplierReference),
        notes: blankToNull(input.notes),
        lines: lines,
        totals: totals,
        createdAt: createdAt,
        updatedAt: now,
      );
      (await _purchases.saveDraft(invoice)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: PurchaseNumbering.sourceType,
          entityId: id,
          action: editing ? 'draft_updated' : 'draft_created',
          summary:
              'Purchase draft ${editing ? 'updated' : 'created'}: '
              '${lines.length} line(s) from ${chosenSupplier.name}, '
              'total ${totals.total}',
          occurredAt: now,
        ),
      )).getOrThrow();
      return invoice;
    });
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
}
