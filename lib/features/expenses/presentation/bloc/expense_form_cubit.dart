import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/utils/date_only.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_amounts.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_input.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/services/expense_calculator.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/save_expense_draft.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the expense form.
final class ExpenseFormState extends Equatable {
  /// Creates a state.
  const ExpenseFormState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.categories = const [],
    this.methods = const [],
    this.taxRates = const [],
    this.currency,
    this.expenseId,
    this.categoryId,
    this.methodId,
    this.taxRateId,
    this.expenseDate,
    this.amount = '',
    this.amountIncludesTax = false,
    this.description = '',
    this.payee = '',
    this.reference = '',
    this.notes = '',
    this.preview,
    this.blockedReason,
    this.fieldErrors = const {},
    this.savedId,
    this.posted = false,
    this.message,
  });

  /// Load status.
  final FormLoadStatus loadStatus;

  /// Submission status.
  final SubmitStatus submitStatus;

  /// Active categories to choose from.
  final List<ExpenseCategory> categories;

  /// Active payment methods to choose from.
  final List<PaymentMethod> methods;

  /// Active tax rates to choose from.
  final List<TaxRate> taxRates;

  /// Active currency.
  final CurrencyConfig? currency;

  /// Id of the draft being edited, `null` when creating.
  final String? expenseId;

  /// Chosen category.
  final String? categoryId;

  /// Chosen payment method.
  final String? methodId;

  /// Chosen tax rate, `null` for none.
  final String? taxRateId;

  /// Chosen date.
  final DateTime? expenseDate;

  /// Amount text.
  final String amount;

  /// Whether the amount includes tax.
  final bool amountIncludesTax;

  /// Description loaded from an existing draft (the page owns the field).
  final String description;

  /// Payee loaded from an existing draft.
  final String payee;

  /// Reference loaded from an existing draft.
  final String reference;

  /// Notes loaded from an existing draft.
  final String notes;

  /// Live net/tax/total for a valid amount, otherwise `null`.
  final ExpenseAmounts? preview;

  /// Why the form cannot be used at all.
  final String? blockedReason;

  /// Field errors of the last submit.
  final Map<String, String> fieldErrors;

  /// Id of the saved draft after a successful submit.
  final String? savedId;

  /// Whether the last successful submit also posted the expense.
  final bool posted;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [fieldErrors] and [message] reset unless provided.
  /// Use the `clear*` flags to reset nullable choices.
  ExpenseFormState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    List<ExpenseCategory>? categories,
    List<PaymentMethod>? methods,
    List<TaxRate>? taxRates,
    CurrencyConfig? currency,
    String? expenseId,
    String? categoryId,
    bool clearCategory = false,
    String? methodId,
    bool clearMethod = false,
    String? taxRateId,
    bool clearTaxRate = false,
    DateTime? expenseDate,
    String? amount,
    bool? amountIncludesTax,
    String? description,
    String? payee,
    String? reference,
    String? notes,
    ExpenseAmounts? preview,
    bool clearPreview = false,
    String? blockedReason,
    Map<String, String>? fieldErrors,
    String? savedId,
    bool? posted,
    String? message,
  }) => ExpenseFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    categories: categories ?? this.categories,
    methods: methods ?? this.methods,
    taxRates: taxRates ?? this.taxRates,
    currency: currency ?? this.currency,
    expenseId: expenseId ?? this.expenseId,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    methodId: clearMethod ? null : (methodId ?? this.methodId),
    taxRateId: clearTaxRate ? null : (taxRateId ?? this.taxRateId),
    expenseDate: expenseDate ?? this.expenseDate,
    amount: amount ?? this.amount,
    amountIncludesTax: amountIncludesTax ?? this.amountIncludesTax,
    description: description ?? this.description,
    payee: payee ?? this.payee,
    reference: reference ?? this.reference,
    notes: notes ?? this.notes,
    preview: clearPreview ? null : (preview ?? this.preview),
    blockedReason: blockedReason ?? this.blockedReason,
    fieldErrors: fieldErrors ?? const {},
    savedId: savedId ?? this.savedId,
    posted: posted ?? this.posted,
    message: message,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    categories,
    methods,
    taxRates,
    currency,
    expenseId,
    categoryId,
    methodId,
    taxRateId,
    expenseDate,
    amount,
    amountIncludesTax,
    description,
    payee,
    reference,
    notes,
    preview,
    blockedReason,
    fieldErrors,
    savedId,
    posted,
    message,
  ];
}

/// Drives the expense form: choices, live amount preview and saving (or
/// saving and posting) the expense.
class ExpenseFormCubit extends Cubit<ExpenseFormState> {
  /// Creates the cubit.
  ExpenseFormCubit({
    required ExpenseRepository expenses,
    required ExpenseCategoryRepository categories,
    required PaymentMethodRepository methods,
    required TaxRateRepository taxRates,
    required SettingsRepository settings,
    required SaveExpenseDraft saveDraft,
    required PostExpense postExpense,
    required Clock clock,
    PreferencesRepository? preferences,
  }) : _preferences = preferences,
       _expenses = expenses,
       _categories = categories,
       _methods = methods,
       _taxRates = taxRates,
       _settings = settings,
       _save = saveDraft,
       _post = postExpense,
       _clock = clock,
       super(const ExpenseFormState());

  final PreferencesRepository? _preferences;
  final ExpenseRepository _expenses;
  final ExpenseCategoryRepository _categories;
  final PaymentMethodRepository _methods;
  final TaxRateRepository _taxRates;
  final SettingsRepository _settings;
  final SaveExpenseDraft _save;
  final PostExpense _post;
  final Clock _clock;

  /// Loads the choices and, for [expenseId], the draft to edit.
  Future<void> load({String? expenseId}) async {
    emit(const ExpenseFormState());
    final categories = await _categories.search();
    final methods = await _methods.list();
    final taxRates = await _taxRates.list();
    final currency = await _settings.getCurrencyConfig();
    final failure =
        categories.failureOrNull ??
        methods.failureOrNull ??
        taxRates.failureOrNull ??
        currency.failureOrNull;
    if (isClosed) {
      return;
    }
    if (failure != null) {
      emit(
        ExpenseFormState(
          loadStatus: FormLoadStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final activeCategories = categories.valueOrNull!;
    final activeMethods = methods.valueOrNull!;
    final activeRates = taxRates.valueOrNull!;
    final config = currency.valueOrNull!;
    final today = dateOnlyUtc(_clock.now().toLocal());

    if (expenseId == null) {
      final defaultMethodId =
          (await _preferences?.load())?.valueOrNull?.defaultPaymentMethodId;
      emit(
        ExpenseFormState(
          loadStatus: FormLoadStatus.ready,
          categories: activeCategories,
          methods: activeMethods,
          methodId: activeMethods.any((m) => m.id == defaultMethodId)
              ? defaultMethodId
              : null,
          taxRates: activeRates,
          currency: config,
          expenseDate: today,
          blockedReason: activeCategories.isEmpty
              ? 'Create an expense category first.'
              : activeMethods.isEmpty
              ? 'Add a payment method first.'
              : null,
        ),
      );
      return;
    }

    final loaded = await _expenses.getById(expenseId);
    if (isClosed) {
      return;
    }
    final loadFailure = loaded.failureOrNull;
    if (loadFailure != null) {
      emit(
        ExpenseFormState(
          loadStatus: loadFailure is NotFoundFailure
              ? FormLoadStatus.notFound
              : FormLoadStatus.failure,
          message: loadFailure.userMessage,
        ),
      );
      return;
    }
    final expense = loaded.valueOrNull!;
    // A choice that was archived since the draft was saved is dropped, so
    // the user must pick a current one.
    final categoryStillActive = activeCategories.any(
      (c) => c.id == expense.categoryId,
    );
    final methodStillActive = activeMethods.any(
      (m) => m.id == expense.methodId,
    );
    final rateStillActive = activeRates.any((t) => t.id == expense.taxRateId);
    final amountText = expense.amountIncludesTax && expense.taxRateBp > 0
        ? expense.amounts.total.toPlainString()
        : expense.amounts.net.toPlainString();
    final next = ExpenseFormState(
      loadStatus: FormLoadStatus.ready,
      categories: activeCategories,
      methods: activeMethods,
      taxRates: activeRates,
      currency: config,
      expenseId: expense.id,
      categoryId: categoryStillActive ? expense.categoryId : null,
      methodId: methodStillActive ? expense.methodId : null,
      taxRateId: rateStillActive ? expense.taxRateId : null,
      expenseDate: expense.expenseDate,
      amount: amountText,
      amountIncludesTax: expense.amountIncludesTax,
      description: expense.description,
      payee: expense.payee ?? '',
      reference: expense.reference ?? '',
      notes: expense.notes ?? '',
      blockedReason: expense.isEditable
          ? null
          : 'Only draft expenses can be edited.',
    );
    emit(_withPreview(next));
  }

  /// Chooses the category.
  void setCategory(String? id) => emit(
    id == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: id),
  );

  /// Chooses the payment method.
  void setMethod(String? id) => emit(
    id == null
        ? state.copyWith(clearMethod: true)
        : state.copyWith(methodId: id),
  );

  /// Chooses the date.
  void setDate(DateTime date) =>
      emit(state.copyWith(expenseDate: dateOnlyUtc(date)));

  /// Updates the amount text and the live preview.
  void setAmount(String text) {
    final next = state.copyWith(amount: text);
    emit(_withPreview(next));
  }

  /// Chooses the tax rate (`null` for none).
  void setTaxRate(String? id) {
    final next = id == null
        ? state.copyWith(clearTaxRate: true)
        : state.copyWith(taxRateId: id);
    emit(_withPreview(next));
  }

  /// Sets whether the amount already includes tax.
  void setIncludesTax({required bool value}) {
    final next = state.copyWith(amountIncludesTax: value);
    emit(_withPreview(next));
  }

  /// Saves the draft; with [post] it is posted right after saving.
  ///
  /// If saving works but posting is refused, the draft stays saved and the
  /// message explains why it was not posted.
  Future<void> submit({
    required String description,
    String payee = '',
    String reference = '',
    String notes = '',
    bool post = false,
  }) async {
    if (state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final saved = await _save(
      ExpenseDraftInput(
        id: state.expenseId,
        categoryId: state.categoryId ?? '',
        expenseDate: state.expenseDate,
        description: description,
        payee: payee,
        amount: state.amount,
        amountIncludesTax: state.amountIncludesTax,
        taxRateId: state.taxRateId,
        methodId: state.methodId ?? '',
        reference: reference,
        notes: notes,
      ),
    );
    if (isClosed) {
      return;
    }
    final failure = saved.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          submitStatus: failure is ValidationFailure
              ? SubmitStatus.validationError
              : SubmitStatus.failure,
          fieldErrors: failure is ValidationFailure
              ? failure.fieldErrors
              : const {},
          message: failure.userMessage,
        ),
      );
      return;
    }
    final expense = saved.valueOrNull!;
    if (!post) {
      emit(
        state.copyWith(
          submitStatus: SubmitStatus.success,
          savedId: expense.id,
          expenseId: expense.id,
        ),
      );
      return;
    }
    final posted = await _post(expense.id);
    if (isClosed) {
      return;
    }
    final postFailure = posted.failureOrNull;
    emit(
      state.copyWith(
        submitStatus: SubmitStatus.success,
        savedId: expense.id,
        expenseId: expense.id,
        posted: postFailure == null,
        message: postFailure == null
            ? null
            : 'Saved as a draft, but not posted: ${postFailure.userMessage}',
      ),
    );
  }

  ExpenseFormState _withPreview(ExpenseFormState from) {
    final preview = _preview(from);
    return preview == null
        ? from.copyWith(clearPreview: true)
        : from.copyWith(preview: preview);
  }

  ExpenseAmounts? _preview(ExpenseFormState from) {
    final currency = from.currency;
    if (currency == null) {
      return null;
    }
    final amount = currency.parse(from.amount.trim());
    if (amount == null ||
        !amount.isPositive ||
        amount.minorUnits > SaveExpenseDraft.maxAmountMinor) {
      return null;
    }
    final rate = from.taxRates.where((t) => t.id == from.taxRateId).firstOrNull;
    final bp = rate == null || rate.isExempt ? 0 : rate.rateBp;
    return ExpenseCalculator.calculate(
      amount: amount,
      includesTax: from.amountIncludesTax,
      taxRateBp: bp,
    );
  }
}
