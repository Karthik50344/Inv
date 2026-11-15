import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';

import 'database_test_helpers.dart';

/// Constraint and trigger tests for the expense tables against the real
/// schema. (Written without a Flutter SDK: not yet executed against Drift.)
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
  });

  tearDown(() async => db.close());

  Future<void> expense(
    String id, {
    String status = 'draft',
    String? number,
    int net = 10000,
    int tax = 0,
    int total = 10000,
    String categoryId = 'ec-rent',
    String methodId = 'pm-cash',
    int? postedAt,
    int? voidedAt,
    String? voidReason,
  }) => db.customStatement(
    'INSERT INTO expenses (id, number, status, expense_date, category_id, '
    'category_name, description, method_id, method_name, currency_code, '
    'decimal_places, amount_includes_tax, tax_rate_bp, net_minor, tax_minor, '
    'total_minor, posted_at, voided_at, void_reason, created_at, updated_at) '
    "VALUES (?, ?, ?, 1, ?, 'Rent', 'Shop rent', ?, 'Cash', 'INR', 2, 0, 0, "
    '?, ?, ?, ?, ?, ?, 1, 1)',
    [
      id,
      number,
      status,
      categoryId,
      methodId,
      net,
      tax,
      total,
      postedAt ?? (status == 'draft' || status == 'cancelled' ? null : 5),
      voidedAt,
      voidReason,
    ],
  );

  Future<void> attach(String id, String owner) => db.customStatement(
    'INSERT INTO attachments (id, owner_type, owner_id, file_name, '
    "stored_path, size_bytes, created_at) VALUES (?, 'expense', ?, 'r.png', "
    "'attachments/r.png', 10, 1)",
    [id, owner],
  );

  test('default expense categories are seeded', () async {
    final rows = await db
        .customSelect('SELECT COUNT(*) AS c FROM expense_categories')
        .getSingle();
    expect(rows.read<int>('c'), 8);
  });

  test('active category names are unique, case-insensitively', () async {
    final failure = await failureOf(
      () => db.customStatement(
        'INSERT INTO expense_categories (id, name, created_at, updated_at) '
        "VALUES ('x', 'RENT', 1, 1)",
      ),
    );
    expect(failure, isA<DuplicateEntryFailure>());
  });

  test('an archived category name can be reused', () async {
    await db.customStatement(
      "UPDATE expense_categories SET archived_at = 9 WHERE id = 'ec-rent'",
    );
    await db.customStatement(
      'INSERT INTO expense_categories (id, name, created_at, updated_at) '
      "VALUES ('x', 'Rent', 1, 1)",
    );
  });

  test('check constraints reject bad amounts and states', () async {
    expect(
      await failureOf(() => expense('a', total: 0, net: 0)),
      isA<ValidationFailure>(),
    );
    expect(
      await failureOf(() => expense('b', net: 5000, tax: 100, total: 10000)),
      isA<ValidationFailure>(),
    );
    expect(
      await failureOf(() => expense('c', status: 'posted')),
      isA<ValidationFailure>(), // posted without a number
    );
    expect(
      await failureOf(() => expense('d', number: 'EXP-000001')),
      isA<ValidationFailure>(), // a draft with a number
    );
    expect(
      await failureOf(() => expense('e', status: 'bogus')),
      isA<ValidationFailure>(),
    );
  });

  test('foreign keys protect categories and payment methods', () async {
    expect(
      await failureOf(() => expense('a', categoryId: 'missing')),
      isA<ValidationFailure>(),
    );
    expect(
      await failureOf(() => expense('b', methodId: 'missing')),
      isA<ValidationFailure>(),
    );
    await expense('c');
    expect(
      await failureOf(
        () => db.customStatement(
          "DELETE FROM expense_categories WHERE id = 'ec-rent'",
        ),
      ),
      isA<ValidationFailure>(),
    );
  });

  test('numbers are unique', () async {
    await expense('a', status: 'posted', number: 'EXP-000001');
    expect(
      await failureOf(
        () => expense('b', status: 'posted', number: 'EXP-000001'),
      ),
      isA<DuplicateEntryFailure>(),
    );
  });

  test(
    'a draft can be edited and posted; a posted expense is immutable',
    () async {
      await expense('a');
      await db.customStatement(
        "UPDATE expenses SET description = 'Changed' WHERE id = 'a'",
      );
      await db.customStatement(
        "UPDATE expenses SET status = 'posted', number = 'EXP-000001', "
        "posted_at = 5 WHERE id = 'a'",
      );
      for (final change in [
        "description = 'Again'",
        'total_minor = 20000, net_minor = 20000',
        "category_name = 'Other'",
        "notes = 'late note'",
        "status = 'draft'",
      ]) {
        expect(
          await failureOf(
            () => db.customStatement(
              "UPDATE expenses SET $change WHERE id = 'a'",
            ),
          ),
          isA<DatabaseFailure>(),
          reason: change,
        );
      }
    },
  );

  test(
    'a posted expense can only change to voided, figures untouched',
    () async {
      await expense('a', status: 'posted', number: 'EXP-000001');
      await db.customStatement(
        "UPDATE expenses SET status = 'voided', voided_at = 7, "
        "void_reason = 'dup' WHERE id = 'a'",
      );
      expect(
        await failureOf(
          () => db.customStatement(
            "UPDATE expenses SET status = 'posted' WHERE id = 'a'",
          ),
        ),
        isA<DatabaseFailure>(),
      );
    },
  );

  test('a void must not smuggle in a changed amount', () async {
    await expense('a', status: 'posted', number: 'EXP-000001');
    expect(
      await failureOf(
        () => db.customStatement(
          "UPDATE expenses SET status = 'voided', voided_at = 7, "
          "void_reason = 'x', net_minor = 1, total_minor = 1 WHERE id = 'a'",
        ),
      ),
      isA<DatabaseFailure>(),
    );
  });

  test('a cancelled draft is frozen', () async {
    await expense('a');
    await db.customStatement(
      "UPDATE expenses SET status = 'cancelled', cancelled_at = 3 "
      "WHERE id = 'a'",
    );
    expect(
      await failureOf(
        () => db.customStatement(
          "UPDATE expenses SET description = 'x' WHERE id = 'a'",
        ),
      ),
      isA<DatabaseFailure>(),
    );
  });

  test('expenses are never deleted', () async {
    await expense('a');
    expect(
      await failureOf(
        () => db.customStatement("DELETE FROM expenses WHERE id = 'a'"),
      ),
      isA<DatabaseFailure>(),
    );
  });

  test(
    'attachments: only for open expenses; removable only from drafts',
    () async {
      expect(
        await failureOf(() => attach('x', 'missing')),
        isA<DatabaseFailure>(),
      );
      await expense('a');
      await attach('a1', 'a');
      await db.customStatement("DELETE FROM attachments WHERE id = 'a1'");
      await attach('a2', 'a');
      await db.customStatement(
        "UPDATE expenses SET status = 'posted', number = 'EXP-000001', "
        "posted_at = 5 WHERE id = 'a'",
      );
      await attach('a3', 'a'); // a late receipt is fine
      expect(
        await failureOf(
          () => db.customStatement("DELETE FROM attachments WHERE id = 'a3'"),
        ),
        isA<DatabaseFailure>(),
      );
      expect(
        await failureOf(
          () => db.customStatement(
            "UPDATE attachments SET file_name = 'z' WHERE id = 'a3'",
          ),
        ),
        isA<DatabaseFailure>(),
      );
      await db.customStatement(
        "UPDATE expenses SET status = 'voided', voided_at = 7, "
        "void_reason = 'x' WHERE id = 'a'",
      );
      expect(await failureOf(() => attach('a4', 'a')), isA<DatabaseFailure>());
    },
  );

  test('integrity check passes', () async {
    expect(await db.integrityCheck(), ['ok']);
  });
}
