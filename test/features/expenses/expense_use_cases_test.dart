import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_input.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import '../../support/expense_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late ExpenseFixture f;

  setUp(() => f = ExpenseFixture());

  Map<String, String> errorsOf(dynamic result) =>
      (result.failureOrNull as ValidationFailure).fieldErrors;

  group('SaveExpenseDraft', () {
    test('saves a draft without number, with snapshots', () async {
      final e = await f.draft(
        with_: f.input(payee: ' Landlord ', reference: 'R-1', notes: 'March'),
      );
      expect(e.status, DocumentStatus.draft);
      expect(e.number, isNull);
      expect(e.displayNumber, 'Draft');
      expect(e.categoryName, 'Rent');
      expect(e.methodName, 'Cash');
      expect(e.payee, 'Landlord');
      expect(e.reference, 'R-1');
      expect(e.amounts.total, inr(100000));
      expect(e.expenseDate, DateTime.utc(2026, 3, 10));
      expect(f.sequences.counters, isEmpty);
      expect(f.audit.entries.single.action, 'draft_created');
    });

    test('tax-exclusive and tax-inclusive amounts', () async {
      f.addTaxRate();
      final ex = await f.draft(with_: f.input(taxRateId: 'gst18'));
      expect(ex.amounts.net, inr(100000));
      expect(ex.amounts.tax, inr(18000));
      expect(ex.amounts.total, inr(118000));
      expect(ex.taxName, 'GST 18%');
      expect(ex.taxRateBp, 1800);
      final inc = await f.draft(
        with_: f.input(
          amount: '1180.00',
          taxRateId: 'gst18',
          includesTax: true,
        ),
      );
      expect(inc.amounts.net, inr(100000));
      expect(inc.amounts.tax, inr(18000));
      expect(inc.amountIncludesTax, isTrue);
    });

    test('exempt tax means no tax and no inclusive flag', () async {
      f.addTaxRate(id: 'ex', name: 'Exempt', bp: 0, exempt: true);
      final e = await f.draft(
        with_: f.input(taxRateId: 'ex', includesTax: true),
      );
      expect(e.amounts.tax, inr(0));
      expect(e.amountIncludesTax, isFalse);
      expect(e.taxName, 'Exempt');
    });

    test('editing a draft keeps id, creation time and attachments', () async {
      final first = await f.draft();
      await f.addAttachment(first.id, '/tmp/receipt.png');
      f.clock.advance(const Duration(hours: 1));
      final edited = await f.draft(
        with_: f.input(id: first.id, amount: '2000', description: 'Rent v2'),
      );
      expect(edited.id, first.id);
      expect(edited.createdAt, first.createdAt);
      expect(edited.updatedAt.isAfter(first.updatedAt), isTrue);
      expect(edited.amounts.total, inr(200000));
      expect(edited.attachments, hasLength(1));
      expect(f.expenses.items, hasLength(1));
      expect(f.audit.entries.last.action, 'draft_updated');
    });

    test('a posted expense cannot be edited', () async {
      final posted = await f.posted();
      final r = await f.saveDraft(f.input(id: posted.id, amount: '5'));
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.expenses.items[posted.id]!.amounts.total, inr(100000));
    });

    test('validates every field', () async {
      final r = await f.saveDraft(
        f.input(categoryId: '', description: ' ', amount: '', methodId: ''),
      );
      final e = errorsOf(r);
      expect(e['categoryId'], isNotNull);
      expect(e['description'], isNotNull);
      expect(e['amount'], isNotNull);
      expect(e['methodId'], isNotNull);
      expect(f.expenses.items, isEmpty);
    });

    test(
      'amount must be a positive number within the currency precision',
      () async {
        for (final bad in ['abc', '0', '0.00', '-5', '10.999', '1e5']) {
          final r = await f.saveDraft(f.input(amount: bad));
          expect(errorsOf(r)['amount'], isNotNull);
        }
        final big = await f.saveDraft(f.input(amount: '20000000000.00'));
        expect(errorsOf(big)['amount'], 'The amount is too large.');
        final ok = await f.saveDraft(f.input(amount: '10000000000.00'));
        expect(ok.isSuccess, isTrue);
      },
    );

    test('date is required and cannot be in the future', () async {
      final missing = await f.saveDraft(
        const ExpenseDraftInput(
          categoryId: 'cat-rent',
          expenseDate: null,
          description: 'Rent',
          amount: '1',
          methodId: 'pm-cash',
        ),
      );
      expect(errorsOf(missing)['expenseDate'], isNotNull);
      final future = await f.saveDraft(
        f.input(date: DateTime.utc(2026, 3, 17)),
      );
      expect(errorsOf(future)['expenseDate'], isNotNull);
      final tomorrow = await f.saveDraft(
        f.input(date: DateTime.utc(2026, 3, 16)),
      );
      expect(tomorrow.isSuccess, isTrue);
    });

    test('date keeps only the day', () async {
      final e = await f.draft(
        with_: f.input(date: DateTime.utc(2026, 3, 10, 23, 59)),
      );
      expect(e.expenseDate, DateTime.utc(2026, 3, 10));
    });

    test('rejects archived or missing category, method and tax rate', () async {
      f.categories.items['cat-rent'] = f.categories.items['cat-rent']!.archived(
        f.clock.now(),
      );
      var r = await f.saveDraft(f.input());
      expect(errorsOf(r)['categoryId'], contains('archived'));
      r = await f.saveDraft(f.input(categoryId: 'nope'));
      expect(errorsOf(r)['categoryId'], contains('no longer exists'));
      r = await f.saveDraft(f.input(methodId: 'nope'));
      expect(errorsOf(r)['methodId'], contains('no longer exists'));
      r = await f.saveDraft(f.input(taxRateId: 'nope'));
      expect(errorsOf(r)['taxRateId'], contains('no longer exists'));
    });

    test('text length limits', () async {
      final r = await f.saveDraft(
        f.input(
          description: 'x' * 121,
          payee: 'p' * 121,
          reference: 'r' * 61,
          notes: 'n' * 501,
        ),
      );
      final e = errorsOf(r);
      expect(
        e.keys,
        containsAll(['description', 'payee', 'reference', 'notes']),
      );
    });

    test('a changed currency blocks editing an old draft', () async {
      final d = await f.draft();
      f.settings.config = const CurrencyConfig(
        currencyCode: 'USD',
        decimalPlaces: 2,
      );
      final r = await f.saveDraft(f.input(id: d.id));
      expect(r.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('PostExpense', () {
    test('posts with a gap-free number and refreshed snapshots', () async {
      final d = await f.draft();
      f.categories.items['cat-rent'] = f.categories.items['cat-rent']!
          .withDetails(name: 'Premises rent', updatedAt: f.clock.now());
      final e = (await f.post(d.id)).valueOrNull!;
      expect(e.status, DocumentStatus.posted);
      expect(e.number, 'EXP-000001');
      expect(e.postedAt, f.clock.now());
      expect(e.categoryName, 'Premises rent');
      expect((await f.posted()).number, 'EXP-000002');
      expect(f.audit.entries.where((a) => a.action == 'posted'), hasLength(2));
    });

    test('posting twice fails and does not use another number', () async {
      final d = await f.draft();
      await f.post(d.id);
      final again = await f.post(d.id);
      expect(again.failureOrNull, isA<ValidationFailure>());
      expect(again.failureOrNull!.message, contains('already posted'));
      expect(f.sequences.counters['expense'], 1);
    });

    test('cancelled and voided expenses cannot be posted', () async {
      final a = await f.draft();
      await f.cancel(a.id);
      expect((await f.post(a.id)).isFailure, isTrue);
      final b = await f.posted();
      await f.voidExpense(b.id, reason: 'x');
      expect((await f.post(b.id)).isFailure, isTrue);
    });

    test('refuses an archived category or method, keeping the draft', () async {
      final d = await f.draft();
      f.categories.items['cat-rent'] = f.categories.items['cat-rent']!.archived(
        f.clock.now(),
      );
      var r = await f.post(d.id);
      expect(r.failureOrNull!.message, contains('archived'));
      f.categories.items['cat-rent'] = f.categories.items['cat-rent']!.restored(
        f.clock.now(),
      );
      f.methods.items['pm-cash'] = PaymentMethod(
        id: 'pm-cash',
        name: 'Cash',
        createdAt: f.clock.now(),
        archivedAt: f.clock.now(),
      );
      r = await f.post(d.id);
      expect(r.failureOrNull!.message, contains('archived'));
      expect(f.expenses.items[d.id]!.status, DocumentStatus.draft);
      expect(f.sequences.counters, isEmpty);
    });

    test('a tampered total is rejected', () async {
      final d = await f.draft(with_: f.input(taxRateId: f.addTaxRate().id));
      f.expenses.tamperTotal(d.id, inr(1));
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.expenses.items[d.id]!.status, DocumentStatus.draft);
    });

    test('rolls back the number and status when a write fails', () async {
      final d = await f.draft();
      f.expenses.postFailure = const DatabaseFailure('disk full');
      final r = await f.post(d.id);
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(f.expenses.items[d.id]!.status, DocumentStatus.draft);
      expect(f.sequences.counters['expense'] ?? 0, 0);
      expect(f.audit.entries.where((a) => a.action == 'posted'), isEmpty);
      f.expenses.postFailure = null;
      expect((await f.post(d.id)).valueOrNull!.number, 'EXP-000001');
    });

    test('rolls back when the audit write fails', () async {
      final d = await f.draft();
      f.audit.recordFailure = const DatabaseFailure('audit down');
      final r = await f.post(d.id);
      expect(r.isFailure, isTrue);
      expect(f.expenses.items[d.id]!.status, DocumentStatus.draft);
      expect(f.sequences.counters['expense'] ?? 0, 0);
    });

    test('unknown id', () async {
      expect((await f.post('zzz')).failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('CancelExpense and VoidExpense', () {
    test('cancel keeps the record', () async {
      final d = await f.draft();
      final c = (await f.cancel(d.id)).valueOrNull!;
      expect(c.status, DocumentStatus.cancelled);
      expect(c.cancelledAt, isNotNull);
      expect(f.expenses.items, hasLength(1));
      expect((await f.cancel(d.id)).isFailure, isTrue);
    });

    test('a posted expense cannot be cancelled', () async {
      final p = await f.posted();
      final r = await f.cancel(p.id);
      expect(r.failureOrNull!.message, contains('Void'));
      expect(f.expenses.items[p.id]!.status, DocumentStatus.posted);
    });

    test('void needs a reason and a posted expense', () async {
      final d = await f.draft();
      expect((await f.voidExpense(d.id, reason: 'oops')).isFailure, isTrue);
      final p = await f.posted();
      final noReason = await f.voidExpense(p.id, reason: '  ');
      expect(errorsOf(noReason)['reason'], isNotNull);
      final v = (await f.voidExpense(p.id, reason: ' duplicate ')).valueOrNull!;
      expect(v.status, DocumentStatus.voided);
      expect(v.voidReason, 'duplicate');
      expect(v.number, p.number);
      expect(v.amounts, p.amounts);
      expect((await f.voidExpense(p.id, reason: 'again')).isFailure, isTrue);
    });

    test('a voided number is not reused', () async {
      final p = await f.posted();
      await f.voidExpense(p.id, reason: 'x');
      expect((await f.posted()).number, 'EXP-000002');
    });
  });

  group('Attachments', () {
    test('attach to a draft and to a posted expense', () async {
      final d = await f.draft();
      var e = (await f.addAttachment(d.id, '/tmp/a.png')).valueOrNull!;
      expect(e.attachments.single.fileName, 'a.png');
      expect(e.attachments.single.isImage, isTrue);
      await f.post(d.id);
      e = (await f.addAttachment(d.id, '/tmp/b.pdf')).valueOrNull!;
      expect(e.attachments, hasLength(2));
      expect(e.attachments.last.isImage, isFalse);
      expect(
        f.audit.entries.where((a) => a.action == 'attachment_added'),
        hasLength(2),
      );
    });

    test(
      'not for cancelled or voided expenses; the file is not stored',
      () async {
        final d = await f.draft();
        await f.cancel(d.id);
        final r = await f.addAttachment(d.id, '/tmp/a.png');
        expect(r.failureOrNull, isA<ValidationFailure>());
        expect(f.storage.stored, isEmpty);
      },
    );

    test('limit of attachments per expense', () async {
      final d = await f.draft();
      for (var i = 0; i < AddExpenseAttachment.maxAttachments; i++) {
        expect((await f.addAttachment(d.id, '/tmp/$i.png')).isSuccess, isTrue);
      }
      final r = await f.addAttachment(d.id, '/tmp/extra.png');
      expect(r.failureOrNull!.message, contains('at most'));
    });

    test('a storage failure is reported and nothing is recorded', () async {
      final d = await f.draft();
      f.storage.storeFailure = const ValidationFailure('Attach a JPG');
      final r = await f.addAttachment(d.id, '/tmp/a.exe');
      expect(r.failureOrNull!.message, 'Attach a JPG');
      expect(f.expenses.items[d.id]!.attachments, isEmpty);
    });

    test('a failed database write deletes the copied file', () async {
      final d = await f.draft();
      f.audit.recordFailure = const DatabaseFailure('audit down');
      final r = await f.addAttachment(d.id, '/tmp/a.png');
      expect(r.isFailure, isTrue);
      expect(f.storage.deleted, f.storage.stored);
      expect(f.expenses.items[d.id]!.attachments, isEmpty);
    });

    test('remove from a draft deletes the file', () async {
      final d = await f.draft();
      final e = (await f.addAttachment(d.id, '/tmp/a.png')).valueOrNull!;
      final id = e.attachments.single.id;
      final r = (await f.removeAttachment(d.id, id)).valueOrNull!;
      expect(r.attachments, isEmpty);
      expect(f.storage.deleted, [e.attachments.single.storedPath]);
    });

    test('attachments of a posted expense are kept', () async {
      final d = await f.draft();
      final e = (await f.addAttachment(d.id, '/tmp/a.png')).valueOrNull!;
      await f.post(d.id);
      final r = await f.removeAttachment(d.id, e.attachments.single.id);
      expect(r.failureOrNull!.message, contains('evidence'));
      expect(f.storage.deleted, isEmpty);
      expect(f.expenses.items[d.id]!.attachments, hasLength(1));
    });

    test('removing an unknown attachment', () async {
      final d = await f.draft();
      final r = await f.removeAttachment(d.id, 'nope');
      expect(r.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('Categories', () {
    test('create validates and rejects duplicates', () async {
      final ok = await f.createCategory(name: ' Utilities ', description: ' ');
      expect(ok.valueOrNull!.name, 'Utilities');
      expect(ok.valueOrNull!.description, isNull);
      final dup = await f.createCategory(name: 'utilities');
      expect(errorsOf(dup)['name'], isNotNull);
      final empty = await f.createCategory(name: ' ');
      expect(errorsOf(empty)['name'], isNotNull);
    });

    test('rename does not rewrite recorded expenses', () async {
      final p = await f.posted();
      final r = await f.updateCategory(id: 'cat-rent', name: 'Premises');
      expect(r.valueOrNull!.name, 'Premises');
      expect(f.expenses.items[p.id]!.categoryName, 'Rent');
    });

    test('rename to an existing name is rejected', () async {
      f.addCategory(id: 'cat-util', name: 'Utilities');
      final r = await f.updateCategory(id: 'cat-util', name: 'rent');
      expect(errorsOf(r)['name'], isNotNull);
    });

    test('archive and restore; restore blocks a name clash', () async {
      expect(
        (await f.setCategoryArchived('cat-rent', archived: true)).isSuccess,
        isTrue,
      );
      expect(f.categories.items['cat-rent']!.isArchived, isTrue);
      expect(
        (await f.setCategoryArchived('cat-rent', archived: true)).isSuccess,
        isTrue,
      );
      await f.createCategory(name: 'Rent');
      final clash = await f.setCategoryArchived('cat-rent', archived: false);
      expect(clash.failureOrNull, isA<ValidationFailure>());
      expect(f.categories.items['cat-rent']!.isArchived, isTrue);
    });

    test('archiving keeps drafts but blocks posting them', () async {
      final d = await f.draft();
      await f.setCategoryArchived('cat-rent', archived: true);
      expect((await f.post(d.id)).isFailure, isTrue);
      await f.setCategoryArchived('cat-rent', archived: false);
      expect((await f.post(d.id)).isSuccess, isTrue);
    });
  });

  group('Report', () {
    ExpenseReportFilter march() => ExpenseReportFilter(
      from: DateTime.utc(2026, 3),
      to: DateTime.utc(2026, 3, 31),
    );

    test('counts only posted expenses of the period', () async {
      f.addCategory(id: 'cat-util', name: 'Utilities');
      f.addTaxRate();
      await f.posted(); // 1000.00 rent
      await f.posted(
        with_: f.input(
          categoryId: 'cat-util',
          amount: '200',
          taxRateId: 'gst18',
        ),
      ); // 236.00
      await f.draft(with_: f.input(amount: '5000')); // draft: ignored
      final voided = await f.posted(with_: f.input(amount: '7000'));
      await f.voidExpense(voided.id, reason: 'x'); // voided: ignored
      final cancelled = await f.draft(with_: f.input(amount: '9000'));
      await f.cancel(cancelled.id);
      await f.posted(with_: f.input(date: DateTime.utc(2026, 2, 28)));

      final report = (await f.expenses.report(march())).valueOrNull!;
      expect(report.count, 2);
      expect(report.total, inr(123600));
      expect(report.net, inr(120000));
      expect(report.tax, inr(3600));
      expect(report.net + report.tax, report.total);
      expect(report.byCategory.map((c) => c.categoryName), [
        'Rent',
        'Utilities',
      ]);
      expect(report.byCategory.first.total, inr(100000));
      expect(
        report.byCategory.fold<Money>(inr(0), (s, c) => s + c.total),
        report.total,
      );
    });

    test('date range is inclusive and the category filter works', () async {
      f.clock.advance(const Duration(days: 40)); // dates up to April are valid
      f.addCategory(id: 'cat-util', name: 'Utilities');
      await f.posted(with_: f.input(date: DateTime.utc(2026, 3)));
      await f.posted(
        with_: f.input(categoryId: 'cat-util', date: DateTime.utc(2026, 3, 31)),
      );
      await f.posted(with_: f.input(date: DateTime.utc(2026, 4)));
      expect((await f.expenses.report(march())).valueOrNull!.count, 2);
      final only = (await f.expenses.report(
        ExpenseReportFilter(
          from: DateTime.utc(2026, 3),
          to: DateTime.utc(2026, 3, 31),
          categoryId: 'cat-util',
        ),
      )).valueOrNull!;
      expect(only.count, 1);
    });

    test('an empty period reports zero', () async {
      final r = (await f.expenses.report(march())).valueOrNull!;
      expect(r.isEmpty, isTrue);
      expect(r.total, inr(0));
    });

    test('a voided expense leaves the totals', () async {
      final p = await f.posted();
      expect(
        (await f.expenses.report(march())).valueOrNull!.total,
        inr(100000),
      );
      await f.voidExpense(p.id, reason: 'x');
      expect((await f.expenses.report(march())).valueOrNull!.total, inr(0));
    });
  });
}
