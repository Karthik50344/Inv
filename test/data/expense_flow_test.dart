import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/data/repositories/drift_expense_category_repository.dart';
import 'package:inventrix/features/expenses/data/repositories/drift_expense_repository.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_filter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_input.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/usecases/cancel_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_categories.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/save_expense_draft.dart';
import 'package:inventrix/features/expenses/domain/usecases/void_expense.dart';
import 'package:inventrix/features/payments/data/repositories/drift_payment_method_repository.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/data/drift_document_sequence_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import '../support/expense_fakes.dart' show FakeAttachmentStorage;
import '../support/fakes.dart';
import 'data_test_support.dart';

/// Audit repository whose writes can be made to fail, to prove rollback.
class _FlakyAudit implements AuditLogRepository {
  _FlakyAudit(this.inner);

  final AuditLogRepository inner;
  bool fail = false;

  @override
  Future<Result<void>> record(AuditEntry entry) async => fail
      ? const Result.failure(DatabaseFailure('audit down'))
      : inner.record(entry);

  @override
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) => inner.forEntity(entityType, entityId, limit: limit);
}

/// End-to-end expense tests on a real in-memory SQLite database.
/// (Written without a Flutter SDK: not yet executed.)
void main() {
  late DataHarness h;
  late DriftExpenseRepository expenses;
  late DriftExpenseCategoryRepository categories;
  late _FlakyAudit audit;
  late FakeAttachmentStorage storage;
  late FakeClock clock;
  late SaveExpenseDraft save;
  late PostExpense post;
  late CancelExpense cancel;
  late VoidExpense voidExpense;
  late AddExpenseAttachment attach;
  late RemoveExpenseAttachment detach;

  Money inr(int minor) =>
      Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

  Future<int> count(String table) async =>
      (await h.db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
          .read<int>('c');

  ExpenseDraftInput input({
    String? id,
    String category = 'ec-rent',
    String amount = '1000.00',
    String description = 'Shop rent',
    DateTime? date,
    String? taxRateId,
    bool includesTax = false,
  }) => ExpenseDraftInput(
    id: id,
    categoryId: category,
    expenseDate: date ?? DateTime.utc(2026, 1, 1),
    description: description,
    amount: amount,
    methodId: 'pm-cash',
    taxRateId: taxRateId,
    amountIncludesTax: includesTax,
  );

  setUp(() async {
    h = DataHarness();
    await h.db.initialize();
    expenses = DriftExpenseRepository(h.db, h.settings);
    categories = DriftExpenseCategoryRepository(h.db);
    final methods = DriftPaymentMethodRepository(h.db);
    audit = _FlakyAudit(DriftAuditLogRepository(h.db));
    storage = FakeAttachmentStorage();
    clock = FakeClock(DateTime.utc(2026, 6, 1, 10));
    final tx = DriftTransactionRunner(h.db);
    final sequences = DriftDocumentSequenceRepository(h.db);
    final ids = SequentialIds();
    save = SaveExpenseDraft(
      expenses: expenses,
      categories: categories,
      methods: methods,
      taxRates: h.taxRates,
      settings: h.settings,
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
    attach = AddExpenseAttachment(
      expenses: expenses,
      storage: storage,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    detach = RemoveExpenseAttachment(
      expenses: expenses,
      storage: storage,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
  });

  tearDown(() async => h.close());

  Future<String> draftId([ExpenseDraftInput? with_]) async =>
      (await save(with_ ?? input())).valueOrNull!.id;

  test('draft round trip keeps every field', () async {
    final id = (await save(input(description: ' Shop rent '))).valueOrNull!.id;
    final e = (await expenses.getById(id)).valueOrNull!;
    expect(e.status, DocumentStatus.draft);
    expect(e.description, 'Shop rent');
    expect(e.categoryName, 'Rent');
    expect(e.methodName, 'Cash');
    expect(e.expenseDate, DateTime.utc(2026, 1, 1));
    expect(e.amounts.total, inr(100000));
    expect(e.number, isNull);
  });

  test('edit a draft, then post: numbered and immutable', () async {
    final id = await draftId();
    await save(input(id: id, amount: '1500'));
    final posted = (await post(id)).valueOrNull!;
    expect(posted.number, 'EXP-000001');
    expect(posted.amounts.total, inr(150000));
    expect((await save(input(id: id))).failureOrNull, isA<ValidationFailure>());
    expect((await post(id)).failureOrNull, isA<ValidationFailure>());
    final second = (await post(await draftId())).valueOrNull!;
    expect(second.number, 'EXP-000002');
  });

  test('tax-inclusive amounts persist and reload', () async {
    final now = t0;
    await h.taxRates.create(
      TaxRate(
        id: 'gst',
        name: 'GST 18%',
        rateBp: 1800,
        isExempt: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final id = await draftId(
      input(amount: '1180', taxRateId: 'gst', includesTax: true),
    );
    final e = (await expenses.getById(id)).valueOrNull!;
    expect(e.amounts.net, inr(100000));
    expect(e.amounts.tax, inr(18000));
    expect(e.amountIncludesTax, isTrue);
    expect(e.taxName, 'GST 18%');
  });

  test(
    'void keeps the posted figures and excludes it from the report',
    () async {
      final id = await draftId();
      await post(id);
      final range = ExpenseReportFilter(
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 1, 31),
      );
      expect((await expenses.report(range)).valueOrNull!.total, inr(100000));
      final voided = (await voidExpense(id, reason: 'duplicate')).valueOrNull!;
      expect(voided.status, DocumentStatus.voided);
      expect(voided.amounts.total, inr(100000));
      expect(voided.number, 'EXP-000001');
      expect((await expenses.report(range)).valueOrNull!.total, inr(0));
      expect((await voidExpense(id, reason: 'again')).isFailure, isTrue);
    },
  );

  test('cancel keeps the record; a cancelled draft cannot be posted', () async {
    final id = await draftId();
    await cancel(id);
    expect(
      (await expenses.getById(id)).valueOrNull!.status,
      DocumentStatus.cancelled,
    );
    expect((await post(id)).isFailure, isTrue);
    expect(await count('expenses'), 1);
  });

  test(
    'a failing audit write rolls the posting back, number included',
    () async {
      final id = await draftId();
      audit.fail = true;
      expect((await post(id)).isFailure, isTrue);
      expect(
        (await expenses.getById(id)).valueOrNull!.status,
        DocumentStatus.draft,
      );
      expect(await count('document_sequences'), 0);
      audit.fail = false;
      expect((await post(id)).valueOrNull!.number, 'EXP-000001');
    },
  );

  test('report totals per category reconcile with the records', () async {
    for (final entry in [
      ('ec-rent', '1000.00', DateTime.utc(2026, 1, 5)),
      ('ec-rent', '250.50', DateTime.utc(2026, 1, 20)),
      ('ec-utilities', '99.99', DateTime.utc(2026, 1, 31)),
      ('ec-utilities', '500.00', DateTime.utc(2026, 2, 1)),
    ]) {
      await post(
        await draftId(
          input(category: entry.$1, amount: entry.$2, date: entry.$3),
        ),
      );
    }
    final january = (await expenses.report(
      ExpenseReportFilter(
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 1, 31),
      ),
    )).valueOrNull!;
    expect(january.count, 3);
    expect(january.total, inr(135049));
    expect(january.byCategory.map((c) => c.categoryName), [
      'Rent',
      'Utilities',
    ]);
    expect(january.byCategory.first.total, inr(125050));
    expect(
      january.byCategory.fold<Money>(inr(0), (s, c) => s + c.total),
      january.total,
    );
    expect(january.net + january.tax, january.total);
  });

  test(
    'posted expenses in another currency are counted but not summed',
    () async {
      final id = await draftId();
      await post(id);
      await h.db.customStatement(
        "UPDATE app_settings SET value = 'USD' WHERE key = 'currency_code'",
      );
      final r = (await expenses.report(
        ExpenseReportFilter(
          from: DateTime.utc(2026, 1, 1),
          to: DateTime.utc(2026, 1, 31),
        ),
      )).valueOrNull!;
      expect(r.count, 0);
      expect(r.otherCurrencyCount, 1);
    },
  );

  test('search filters by text, status, category and date', () async {
    await post(await draftId(input(description: 'March rent')));
    await draftId(
      input(
        description: 'Electricity bill',
        category: 'ec-utilities',
        date: DateTime.utc(2026, 2, 10),
      ),
    );
    Future<List<String>> names(ExpenseFilter f) async => [
      for (final s in (await expenses.search(f)).valueOrNull!) s.description,
    ];
    expect(await names(const ExpenseFilter()), hasLength(2));
    expect(await names(const ExpenseFilter(query: 'ELECTRIC')), [
      'Electricity bill',
    ]);
    expect(await names(const ExpenseFilter(query: '100%')), isEmpty);
    expect(await names(const ExpenseFilter(status: DocumentStatus.posted)), [
      'March rent',
    ]);
    expect(await names(const ExpenseFilter(categoryId: 'ec-utilities')), [
      'Electricity bill',
    ]);
    expect(
      await names(
        ExpenseFilter(
          from: DateTime.utc(2026, 2),
          to: DateTime.utc(2026, 2, 28),
        ),
      ),
      ['Electricity bill'],
    );
    // Newest expense date first.
    expect((await names(const ExpenseFilter())).first, 'Electricity bill');
  });

  test(
    'attachments: add to a draft and posted expense, remove from draft',
    () async {
      final id = await draftId();
      var e = (await attach(id, '/tmp/a.png')).valueOrNull!;
      expect(e.attachments, hasLength(1));
      expect(await count('attachments'), 1);
      e = (await detach(id, e.attachments.single.id)).valueOrNull!;
      expect(e.attachments, isEmpty);
      expect(storage.deleted, hasLength(1));
      await attach(id, '/tmp/b.pdf');
      await post(id);
      e = (await attach(id, '/tmp/c.png')).valueOrNull!;
      expect(e.attachments, hasLength(2));
      final removal = await detach(id, e.attachments.first.id);
      expect(removal.isFailure, isTrue);
      expect(await count('attachments'), 2);
    },
  );

  test('a failed attachment write deletes the copied file', () async {
    final id = await draftId();
    audit.fail = true;
    expect((await attach(id, '/tmp/a.png')).isFailure, isTrue);
    expect(storage.deleted, storage.stored);
    expect(await count('attachments'), 0);
  });

  group('categories', () {
    late CreateExpenseCategory create;
    late UpdateExpenseCategory update;
    late SetExpenseCategoryArchived archive;

    setUp(() {
      final ids = SequentialIds();
      create = CreateExpenseCategory(
        categories: categories,
        ids: ids,
        clock: clock,
      );
      update = UpdateExpenseCategory(categories: categories, clock: clock);
      archive = SetExpenseCategoryArchived(
        categories: categories,
        clock: clock,
      );
    });

    test('defaults exist; duplicate names are rejected', () async {
      expect((await categories.search()).valueOrNull, hasLength(8));
      final dup = await create(name: 'rent');
      expect(dup.failureOrNull, isA<ValidationFailure>());
      expect((await create(name: 'Insurance')).isSuccess, isTrue);
      expect(
        (await categories.search(query: 'insur')).valueOrNull,
        hasLength(1),
      );
    });

    test(
      'archive hides, restore brings back; names stay on expenses',
      () async {
        final id = await draftId();
        await post(id);
        await update(id: 'ec-rent', name: 'Premises');
        expect((await expenses.getById(id)).valueOrNull!.categoryName, 'Rent');
        await archive('ec-rent', archived: true);
        expect((await categories.search()).valueOrNull, hasLength(7));
        expect(
          (await categories.search(includeArchived: true)).valueOrNull,
          hasLength(8),
        );
        expect((await save(input())).failureOrNull, isA<ValidationFailure>());
        await archive('ec-rent', archived: false);
        expect((await save(input())).isSuccess, isTrue);
      },
    );
  });
}
