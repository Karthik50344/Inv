import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/sales_line_builder.dart';
import 'package:inventrix/features/sales/domain/services/sales_stock_check.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Creates a sale draft or replaces the content of an existing draft.
///
/// A draft never touches inventory. Validation and money arithmetic live
/// here (and in [SalesLineBuilder]), not in the UI.
final class SaveSalesDraft {
  /// Creates the use case.
  const SaveSalesDraft({
    required SalesRepository sales,
    required CustomerRepository customers,
    required SalesLineBuilder lineBuilder,
    required SalesStockCheck stockCheck,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _sales = sales,
       _customers = customers,
       _lineBuilder = lineBuilder,
       _stockCheck = stockCheck,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final SalesRepository _sales;
  final CustomerRepository _customers;
  final SalesLineBuilder _lineBuilder;
  final SalesStockCheck _stockCheck;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Maximum number of lines on one invoice.
  static const int maxLines = 200;

  /// Validates [input] and saves the draft.
  ///
  /// Field errors use the keys `customerId`, `invoiceDate`, `dueDate`,
  /// `customerReference`, `notes`, `lines` and `lines.<index>.<field>`.
  Future<Result<SalesInvoice>> call(SalesDraftInput input) async {
    final currencyResult = await _settings.getCurrencyConfig();
    final currency = currencyResult.valueOrNull;
    if (currency == null) {
      return Result.failure(currencyResult.failureOrNull!);
    }

    final errors = FieldErrors();
    Customer? customer;
    final customerId = input.customerId?.trim() ?? '';
    // No customer is a walk-in sale.
    if (customerId.isNotEmpty) {
      final found = await _customers.getById(customerId);
      customer = found.valueOrNull;
      final failure = found.failureOrNull;
      if (failure != null) {
        if (failure is! NotFoundFailure) {
          return Result.failure(failure);
        }
        errors.add('customerId', 'This customer no longer exists.');
      } else if (customer!.isArchived) {
        errors.add(
          'customerId',
          'This customer is archived. Restore it before selling to them.',
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
        'customerReference',
        Validators.optionalText(
          input.customerReference,
          label: 'Customer reference',
          maxLength: 60,
        ),
      )
      ..add(
        'notes',
        Validators.optionalText(input.notes, label: 'Notes', maxLength: 500),
      );

    final lines = <SalesLine>[];
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
    if (errors.isEmpty) {
      // Available stock, cumulative per product across the lines.
      final shortages = await _stockCheck.findShortages(lines);
      final found = shortages.valueOrNull;
      if (found == null) {
        return Result.failure(shortages.failureOrNull!);
      }
      found.forEach(
        (index, message) => errors.add('lines.$index.quantity', message),
      );
    }
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }

    final chosenCustomer = customer;
    final now = _clock.now();
    final id = input.id ?? _ids.newId();
    final totals = SalesTotals.fromLines(lines, zero: currency.zero());

    return _transactions.runResult(() async {
      var createdAt = now;
      final editing = input.id != null;
      if (editing) {
        final existing = (await _sales.getById(id)).getOrThrow();
        if (!existing.isEditable) {
          throw const FailureException(
            ValidationFailure('Only draft sales can be edited.'),
          );
        }
        final stored = existing.totals.total;
        if (stored.currencyCode != currency.currencyCode ||
            stored.decimalPlaces != currency.decimalPlaces) {
          throw const FailureException(
            ValidationFailure(
              'The currency changed after this draft was created. '
              'Create a new sale instead.',
            ),
          );
        }
        createdAt = existing.createdAt;
      }
      final invoice = SalesInvoice(
        id: id,
        customerId: chosenCustomer?.id,
        customerName: chosenCustomer?.name ?? SalesInvoice.walkInCustomerName,
        status: DocumentStatus.draft,
        invoiceDate: invoiceDate!,
        dueDate: dueDate,
        customerReference: blankToNull(input.customerReference),
        notes: blankToNull(input.notes),
        lines: lines,
        totals: totals,
        createdAt: createdAt,
        updatedAt: now,
      );
      (await _sales.saveDraft(invoice)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: SalesNumbering.sourceType,
          entityId: id,
          action: editing ? 'draft_updated' : 'draft_created',
          summary:
              'Sales draft ${editing ? 'updated' : 'created'}: '
              '${lines.length} line(s) for '
              '${chosenCustomer?.name ?? SalesInvoice.walkInCustomerName}, '
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
