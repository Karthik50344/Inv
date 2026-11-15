import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_amounts.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_filter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_input.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_summary.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/usecases/cancel_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_categories.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/save_expense_draft.dart';
import 'package:inventrix/features/expenses/domain/usecases/void_expense.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import 'fakes.dart';
import 'inventory_fakes.dart';
import 'payment_fakes.dart';
import 'purchase_fakes.dart';

/// In-memory expenses that emulate the SQL rules: guarded status changes,
/// immutable posted rows, attachments open only for draft/posted expenses.
class FakeExpenseRepository implements ExpenseRepository, Rollbackable {
  Map<String, Expense> items = {};
  CurrencyConfig currency = const CurrencyConfig(
    currencyCode: 'INR',
    decimalPlaces: 2,
  );

  /// Makes `markPosted` fail (to test rollback).
  Failure? postFailure;

  @override
  Object snapshot() => Map<String, Expense>.of(items);

  @override
  void restore(Object snapshot) =>
      items = Map<String, Expense>.of(snapshot as Map<String, Expense>);

  @override
  Future<Result<List<ExpenseSummary>>> search(ExpenseFilter f) async {
    final q = f.query.trim().toLowerCase();
    final list = items.values.where((e) {
      if (f.status != null && e.status != f.status) return false;
      if (f.categoryId != null && e.categoryId != f.categoryId) return false;
      if (f.from != null && e.expenseDate.isBefore(f.from!)) return false;
      if (f.to != null && e.expenseDate.isAfter(f.to!)) return false;
      if (q.isNotEmpty) {
        final hay = [
          e.number ?? '',
          e.description,
          e.payee ?? '',
          e.categoryName,
          e.reference ?? '',
        ].join('|').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return Result.success([
      for (final e in list)
        ExpenseSummary(
          id: e.id,
          number: e.number,
          status: e.status,
          expenseDate: e.expenseDate,
          categoryId: e.categoryId,
          categoryName: e.categoryName,
          description: e.description,
          payee: e.payee,
          methodName: e.methodName,
          total: e.amounts.total,
        ),
    ]);
  }

  @override
  Future<Result<Expense>> getById(String id) async => items[id] == null
      ? const Result.failure(NotFoundFailure('Expense not found.'))
      : Result.success(items[id]!);

  Expense _copy(
    Expense e, {
    DocumentStatus? status,
    String? number,
    String? categoryName,
    String? methodName,
    List<ExpenseAttachment>? attachments,
    ExpenseAmounts? amounts,
    DateTime? at,
    DateTime? postedAt,
    DateTime? cancelledAt,
    DateTime? voidedAt,
    String? voidReason,
  }) => Expense(
    id: e.id,
    number: number ?? e.number,
    status: status ?? e.status,
    expenseDate: e.expenseDate,
    categoryId: e.categoryId,
    categoryName: categoryName ?? e.categoryName,
    description: e.description,
    payee: e.payee,
    methodId: e.methodId,
    methodName: methodName ?? e.methodName,
    reference: e.reference,
    notes: e.notes,
    amountIncludesTax: e.amountIncludesTax,
    taxRateId: e.taxRateId,
    taxName: e.taxName,
    taxRateBp: e.taxRateBp,
    amounts: amounts ?? e.amounts,
    attachments: attachments ?? e.attachments,
    createdAt: e.createdAt,
    updatedAt: at ?? e.updatedAt,
    postedAt: postedAt ?? e.postedAt,
    cancelledAt: cancelledAt ?? e.cancelledAt,
    voidedAt: voidedAt ?? e.voidedAt,
    voidReason: voidReason ?? e.voidReason,
  );

  /// Test helper: overwrites the stored total (simulates tampering).
  void tamperTotal(String id, Money total) {
    final e = items[id]!;
    items[id] = _copy(
      e,
      amounts: ExpenseAmounts(
        net: e.amounts.net,
        tax: e.amounts.tax,
        total: total,
      ),
    );
  }

  @override
  Future<Result<void>> saveDraft(Expense expense) async {
    final existing = items[expense.id];
    if (existing != null && existing.status != DocumentStatus.draft) {
      return const Result.failure(
        ValidationFailure('Only draft expenses can be edited.'),
      );
    }
    items[expense.id] = _copy(
      expense,
      attachments: existing?.attachments ?? const [],
    );
    return const Result.success(null);
  }

  Result<Expense> _guard(String id, Set<DocumentStatus> from) {
    final e = items[id];
    if (e == null) {
      return const Result.failure(NotFoundFailure('Expense not found.'));
    }
    if (!from.contains(e.status)) {
      return const Result.failure(
        ValidationFailure('This expense was changed in the meantime.'),
      );
    }
    return Result.success(e);
  }

  @override
  Future<Result<void>> markCancelled(String id, {required DateTime at}) async {
    final g = _guard(id, {DocumentStatus.draft});
    final e = g.valueOrNull;
    if (e == null) return Result.failure(g.failureOrNull!);
    items[id] = _copy(
      e,
      status: DocumentStatus.cancelled,
      cancelledAt: at,
      at: at,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> markPosted(
    String id, {
    required String number,
    required String categoryName,
    required String methodName,
    required DateTime at,
  }) async {
    if (postFailure != null) return Result.failure(postFailure!);
    final g = _guard(id, {DocumentStatus.draft});
    final e = g.valueOrNull;
    if (e == null) return Result.failure(g.failureOrNull!);
    items[id] = _copy(
      e,
      status: DocumentStatus.posted,
      number: number,
      categoryName: categoryName,
      methodName: methodName,
      postedAt: at,
      at: at,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> markVoided(
    String id, {
    required String reason,
    required DateTime at,
  }) async {
    final g = _guard(id, {DocumentStatus.posted});
    final e = g.valueOrNull;
    if (e == null) return Result.failure(g.failureOrNull!);
    items[id] = _copy(
      e,
      status: DocumentStatus.voided,
      voidedAt: at,
      voidReason: reason,
      at: at,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> addAttachment(ExpenseAttachment attachment) async {
    final e = items[attachment.expenseId];
    if (e == null ||
        (e.status != DocumentStatus.draft &&
            e.status != DocumentStatus.posted)) {
      return const Result.failure(
        DatabaseFailure('expense is not open for attachments'),
      );
    }
    items[e.id] = _copy(e, attachments: [...e.attachments, attachment]);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> removeAttachment(String attachmentId) async {
    for (final e in items.values) {
      if (e.attachments.any((a) => a.id == attachmentId)) {
        if (e.status != DocumentStatus.draft) {
          return const Result.failure(
            DatabaseFailure('attachments of posted expenses are kept'),
          );
        }
        items[e.id] = _copy(
          e,
          attachments: [
            for (final a in e.attachments)
              if (a.id != attachmentId) a,
          ],
        );
        return const Result.success(null);
      }
    }
    return const Result.failure(NotFoundFailure('attachment'));
  }

  @override
  Future<Result<ExpenseReport>> report(ExpenseReportFilter f) async {
    final posted = items.values.where(
      (e) =>
          e.status == DocumentStatus.posted &&
          !e.expenseDate.isBefore(f.from) &&
          !e.expenseDate.isAfter(f.to) &&
          (f.categoryId == null || e.categoryId == f.categoryId),
    );
    bool same(Expense e) =>
        e.amounts.total.currencyCode == currency.currencyCode &&
        e.amounts.total.decimalPlaces == currency.decimalPlaces;
    final counted = posted.where(same).toList();
    final groups = <String, List<Expense>>{};
    for (final e in counted) {
      groups.putIfAbsent(e.categoryId, () => []).add(e);
    }
    final totals = [
      for (final entry in groups.entries)
        ExpenseCategoryTotal(
          categoryId: entry.key,
          categoryName: entry.value.first.categoryName,
          count: entry.value.length,
          net: entry.value.fold(
            currency.zero(),
            (sum, e) => sum + e.amounts.net,
          ),
          tax: entry.value.fold(
            currency.zero(),
            (sum, e) => sum + e.amounts.tax,
          ),
          total: entry.value.fold(
            currency.zero(),
            (sum, e) => sum + e.amounts.total,
          ),
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return Result.success(
      ExpenseReport(
        filter: f,
        count: counted.length,
        net: totals.fold(currency.zero(), (s, t) => s + t.net),
        tax: totals.fold(currency.zero(), (s, t) => s + t.tax),
        total: totals.fold(currency.zero(), (s, t) => s + t.total),
        byCategory: totals,
        otherCurrencyCount: posted.length - counted.length,
      ),
    );
  }
}

/// In-memory expense categories.
class FakeExpenseCategoryRepository implements ExpenseCategoryRepository {
  final Map<String, ExpenseCategory> items = {};

  @override
  Future<Result<List<ExpenseCategory>>> search({
    String query = '',
    bool includeArchived = false,
  }) async => Result.success(
    [
      for (final c in items.values)
        if ((includeArchived || !c.isArchived) &&
            c.name.toLowerCase().contains(query.trim().toLowerCase()))
          c,
    ]..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Future<Result<ExpenseCategory>> getById(String id) async => items[id] == null
      ? const Result.failure(NotFoundFailure('Expense category not found.'))
      : Result.success(items[id]!);

  @override
  Future<Result<bool>> nameExists(String name, {String? excludeId}) async =>
      Result.success(
        items.values.any(
          (c) =>
              !c.isArchived &&
              c.id != excludeId &&
              c.name.toLowerCase() == name.trim().toLowerCase(),
        ),
      );

  @override
  Future<Result<void>> create(ExpenseCategory category) async {
    final clash = items.values.any(
      (c) =>
          !c.isArchived && c.name.toLowerCase() == category.name.toLowerCase(),
    );
    if (clash) return const Result.failure(DuplicateEntryFailure('dup'));
    items[category.id] = category;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> update(ExpenseCategory category) async {
    items[category.id] = category;
    return const Result.success(null);
  }
}

/// Attachment storage that records stored and deleted paths.
class FakeAttachmentStorage implements AttachmentStorage {
  final List<String> stored = [];
  final List<String> deleted = [];
  Failure? storeFailure;
  int _n = 0;

  @override
  Future<Result<StoredAttachment>> store(String sourcePath) async {
    if (storeFailure != null) return Result.failure(storeFailure!);
    final name = sourcePath.split('/').last;
    final path = 'attachments/${++_n}_$name';
    stored.add(path);
    return Result.success(
      StoredAttachment(
        relativePath: path,
        fileName: name,
        mimeType: name.endsWith('.pdf') ? 'application/pdf' : 'image/png',
        sizeBytes: 1234,
      ),
    );
  }

  @override
  Future<String> resolvePath(String relativePath) async => '/app/$relativePath';

  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);
}

/// Wires every expense use case on in-memory fakes with rollback emulation.
class ExpenseFixture {
  ExpenseFixture() {
    tx = FakeTransactionRunner([expenses, sequences, audit]);
    saveDraft = SaveExpenseDraft(
      expenses: expenses,
      categories: categories,
      methods: methods,
      taxRates: taxRates,
      settings: settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    post = PostExpense(
      expenses: expenses,
      categories: categories,
      methods: methods,
      sequences: sequences,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    cancel = CancelExpense(
      expenses: expenses,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    voidExpense = VoidExpense(
      expenses: expenses,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    addAttachment = AddExpenseAttachment(
      expenses: expenses,
      storage: storage,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    removeAttachment = RemoveExpenseAttachment(
      expenses: expenses,
      storage: storage,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    createCategory = CreateExpenseCategory(
      categories: categories,
      ids: ids,
      clock: clock,
    );
    updateCategory = UpdateExpenseCategory(
      categories: categories,
      clock: clock,
    );
    setCategoryArchived = SetExpenseCategoryArchived(
      categories: categories,
      clock: clock,
    );
    addCategory();
    addMethod();
  }

  final FakeClock clock = FakeClock(DateTime.utc(2026, 3, 15, 10));
  final SequentialIds ids = SequentialIds();
  final FakeSettingsRepository settings = FakeSettingsRepository();
  final FakeTaxRateRepository taxRates = FakeTaxRateRepository();
  final FakePaymentMethodRepository methods = FakePaymentMethodRepository();
  final FakeAuditLogRepository audit = FakeAuditLogRepository();
  final FakeDocumentSequenceRepository sequences =
      FakeDocumentSequenceRepository();
  final FakeExpenseRepository expenses = FakeExpenseRepository();
  final FakeExpenseCategoryRepository categories =
      FakeExpenseCategoryRepository();
  final FakeAttachmentStorage storage = FakeAttachmentStorage();
  late final FakeTransactionRunner tx;
  late final SaveExpenseDraft saveDraft;
  late final PostExpense post;
  late final CancelExpense cancel;
  late final VoidExpense voidExpense;
  late final AddExpenseAttachment addAttachment;
  late final RemoveExpenseAttachment removeAttachment;
  late final CreateExpenseCategory createCategory;
  late final UpdateExpenseCategory updateCategory;
  late final SetExpenseCategoryArchived setCategoryArchived;

  ExpenseCategory addCategory({String id = 'cat-rent', String name = 'Rent'}) {
    final now = clock.now();
    final category = ExpenseCategory(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    categories.items[id] = category;
    return category;
  }

  PaymentMethod addMethod({String id = 'pm-cash', String name = 'Cash'}) {
    final method = PaymentMethod(id: id, name: name, createdAt: clock.now());
    methods.items[id] = method;
    return method;
  }

  TaxRate addTaxRate({
    String id = 'gst18',
    String name = 'GST 18%',
    int bp = 1800,
    bool exempt = false,
  }) {
    final now = clock.now();
    final rate = TaxRate(
      id: id,
      name: name,
      rateBp: bp,
      isExempt: exempt,
      createdAt: now,
      updatedAt: now,
    );
    taxRates.items[id] = rate;
    return rate;
  }

  /// A valid input; override fields as needed.
  ExpenseDraftInput input({
    String? id,
    String categoryId = 'cat-rent',
    DateTime? date,
    String description = 'Shop rent',
    String amount = '1000.00',
    String methodId = 'pm-cash',
    String payee = '',
    bool includesTax = false,
    String? taxRateId,
    String reference = '',
    String notes = '',
  }) => ExpenseDraftInput(
    id: id,
    categoryId: categoryId,
    expenseDate: date ?? DateTime.utc(2026, 3, 10),
    description: description,
    amount: amount,
    methodId: methodId,
    payee: payee,
    amountIncludesTax: includesTax,
    taxRateId: taxRateId,
    reference: reference,
    notes: notes,
  );

  /// Saves a draft and returns it (fails the test on a failure).
  Future<Expense> draft({ExpenseDraftInput? with_}) async {
    final result = await saveDraft(with_ ?? input());
    final value = result.valueOrNull;
    if (value == null) {
      throw StateError('draft failed: ${result.failureOrNull}');
    }
    return value;
  }

  /// Saves and posts an expense.
  Future<Expense> posted({ExpenseDraftInput? with_}) async {
    final d = await draft(with_: with_);
    final result = await post(d.id);
    final value = result.valueOrNull;
    if (value == null) {
      throw StateError('post failed: ${result.failureOrNull}');
    }
    return value;
  }
}
