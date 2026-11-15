import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/utils/date_only.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_input.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/services/expense_calculator.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Creates an expense draft or replaces the content of an existing draft.
///
/// A draft has no number and is not counted in reports. Validation and the
/// money arithmetic live here (and in `ExpenseCalculator`), not in the UI.
final class SaveExpenseDraft {
  /// Creates the use case.
  const SaveExpenseDraft({
    required ExpenseRepository expenses,
    required ExpenseCategoryRepository categories,
    required PaymentMethodRepository methods,
    required TaxRateRepository taxRates,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _expenses = expenses,
       _categories = categories,
       _methods = methods,
       _taxRates = taxRates,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final ExpenseRepository _expenses;
  final ExpenseCategoryRepository _categories;
  final PaymentMethodRepository _methods;
  final TaxRateRepository _taxRates;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Largest amount accepted, in minor units. Keeps later sums far away
  /// from integer overflow.
  static const int maxAmountMinor = 1000000000000;

  /// Validates [input] and saves the draft.
  ///
  /// Field errors use the keys `categoryId`, `expenseDate`, `description`,
  /// `payee`, `amount`, `taxRateId`, `methodId`, `reference` and `notes`.
  Future<Result<Expense>> call(ExpenseDraftInput input) async {
    final currencyResult = await _settings.getCurrencyConfig();
    final currency = currencyResult.valueOrNull;
    if (currency == null) {
      return Result.failure(currencyResult.failureOrNull!);
    }
    final now = _clock.now();
    final errors = FieldErrors();

    // Category.
    var categoryName = '';
    if (input.categoryId.trim().isEmpty) {
      errors.add('categoryId', 'Choose a category.');
    } else {
      final found = await _categories.getById(input.categoryId);
      final category = found.valueOrNull;
      final failure = found.failureOrNull;
      if (failure != null) {
        if (failure is! NotFoundFailure) {
          return Result.failure(failure);
        }
        errors.add('categoryId', 'This category no longer exists.');
      } else if (category!.isArchived) {
        errors.add(
          'categoryId',
          'This category is archived. Choose another or restore it.',
        );
      } else {
        categoryName = category.name;
      }
    }

    // Payment method.
    var methodName = '';
    if (input.methodId.trim().isEmpty) {
      errors.add('methodId', 'Choose a payment method.');
    } else {
      final found = await _methods.getById(input.methodId);
      final method = found.valueOrNull;
      final failure = found.failureOrNull;
      if (failure != null) {
        if (failure is! NotFoundFailure) {
          return Result.failure(failure);
        }
        errors.add('methodId', 'This payment method no longer exists.');
      } else if (method!.isArchived) {
        errors.add('methodId', 'This payment method is archived.');
      } else {
        methodName = method.name;
      }
    }

    // Tax.
    var taxRateBp = 0;
    String? taxName;
    final taxRateId = blankToNull(input.taxRateId);
    if (taxRateId != null) {
      final found = await _taxRates.getById(taxRateId);
      final tax = found.valueOrNull;
      final failure = found.failureOrNull;
      if (failure != null) {
        if (failure is! NotFoundFailure) {
          return Result.failure(failure);
        }
        errors.add('taxRateId', 'This tax rate no longer exists.');
      } else if (tax!.isArchived) {
        errors.add('taxRateId', 'This tax rate is archived.');
      } else {
        taxRateBp = tax.isExempt ? 0 : tax.rateBp;
        taxName = tax.name;
      }
    }

    // Date.
    final expenseDate = input.expenseDate == null
        ? null
        : dateOnlyUtc(input.expenseDate!);
    if (expenseDate == null) {
      errors.add('expenseDate', 'Expense date is required.');
    } else if (expenseDate.isAfter(
      dateOnlyUtc(now).add(const Duration(days: 1)),
    )) {
      errors.add('expenseDate', 'The date cannot be in the future.');
    }

    // Text fields.
    errors
      ..add(
        'description',
        Validators.requiredText(
          input.description,
          label: 'Description',
          maxLength: 120,
        ),
      )
      ..add(
        'payee',
        Validators.optionalText(input.payee, label: 'Payee', maxLength: 120),
      )
      ..add(
        'reference',
        Validators.optionalText(
          input.reference,
          label: 'Reference',
          maxLength: 60,
        ),
      )
      ..add(
        'notes',
        Validators.optionalText(input.notes, label: 'Notes', maxLength: 500),
      );

    // Amount.
    final amount = currency.parse(input.amount.trim());
    if (input.amount.trim().isEmpty) {
      errors.add('amount', 'Amount is required.');
    } else if (amount == null) {
      errors.add(
        'amount',
        currency.decimalPlaces == 0
            ? 'Enter a whole number.'
            : 'Enter a number with up to ${currency.decimalPlaces} '
                  'decimal places.',
      );
    } else if (!amount.isPositive) {
      errors.add('amount', 'The amount must be greater than zero.');
    } else if (amount.minorUnits > maxAmountMinor) {
      errors.add('amount', 'The amount is too large.');
    }

    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }

    // With no tax to split, "includes tax" has no meaning: store false.
    final includesTax = input.amountIncludesTax && taxRateBp > 0;
    final amounts = ExpenseCalculator.calculate(
      amount: amount!,
      includesTax: includesTax,
      taxRateBp: taxRateBp,
    );
    final id = input.id ?? _ids.newId();
    final editing = input.id != null;

    return _transactions.runResult(() async {
      var createdAt = now;
      var attachments = const <ExpenseAttachment>[];
      if (editing) {
        final existing = (await _expenses.getById(id)).getOrThrow();
        if (!existing.isEditable) {
          throw const FailureException(
            ValidationFailure('Only draft expenses can be edited.'),
          );
        }
        final stored = existing.amounts.total;
        if (stored.currencyCode != currency.currencyCode ||
            stored.decimalPlaces != currency.decimalPlaces) {
          throw const FailureException(
            ValidationFailure(
              'The currency changed after this draft was created. '
              'Create a new expense instead.',
            ),
          );
        }
        createdAt = existing.createdAt;
        attachments = existing.attachments;
      }
      final expense = Expense(
        id: id,
        status: DocumentStatus.draft,
        expenseDate: expenseDate!,
        categoryId: input.categoryId,
        categoryName: categoryName,
        description: input.description.trim(),
        payee: blankToNull(input.payee),
        methodId: input.methodId,
        methodName: methodName,
        reference: blankToNull(input.reference),
        notes: blankToNull(input.notes),
        amountIncludesTax: includesTax,
        taxRateId: taxRateId,
        taxName: taxName,
        taxRateBp: taxRateBp,
        amounts: amounts,
        attachments: attachments,
        createdAt: createdAt,
        updatedAt: now,
      );
      (await _expenses.saveDraft(expense)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: ExpenseNumbering.sourceType,
          entityId: id,
          action: editing ? 'draft_updated' : 'draft_created',
          summary:
              'Expense draft ${editing ? 'updated' : 'created'}: '
              '${expense.description}, total ${amounts.total}',
          occurredAt: now,
        ),
      )).getOrThrow();
      return expense;
    });
  }
}
