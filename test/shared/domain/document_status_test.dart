import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  group('DocumentStatus', () {
    test('round-trips through its stored name', () {
      for (final status in DocumentStatus.values) {
        expect(DocumentStatus.fromDbName(status.dbName), status);
      }
      expect(() => DocumentStatus.fromDbName('nope'), throwsArgumentError);
    });

    test('only drafts are editable and only posted documents are posted', () {
      expect(DocumentStatus.draft.isEditable, isTrue);
      expect(DocumentStatus.pendingApproval.isEditable, isFalse);
      expect(DocumentStatus.posted.isEditable, isFalse);
      expect(DocumentStatus.posted.isPosted, isTrue);
      expect(DocumentStatus.voided.isPosted, isFalse);
    });

    test('approval workflow transitions', () {
      expect(
        DocumentStatus.draft.canTransitionTo(DocumentStatus.pendingApproval),
        isTrue,
      );
      expect(
        DocumentStatus.pendingApproval.canTransitionTo(DocumentStatus.approved),
        isTrue,
      );
      expect(
        DocumentStatus.approved.canTransitionTo(DocumentStatus.posted),
        isTrue,
      );
      expect(
        DocumentStatus.pendingApproval.canTransitionTo(DocumentStatus.posted),
        isFalse,
      );
    });

    test('posted documents can only be voided; final states are final', () {
      expect(
        DocumentStatus.posted.canTransitionTo(DocumentStatus.voided),
        isTrue,
      );
      expect(
        DocumentStatus.posted.canTransitionTo(DocumentStatus.draft),
        isFalse,
      );
      expect(
        DocumentStatus.posted.canTransitionTo(DocumentStatus.cancelled),
        isFalse,
      );
      expect(DocumentStatus.cancelled.isFinal, isTrue);
      expect(DocumentStatus.voided.isFinal, isTrue);
      expect(DocumentStatus.posted.isFinal, isFalse);
    });
  });

  group('Discount', () {
    test('none applies nothing', () {
      expect(const Discount.none().appliedTo(inr(1000)), inr(0));
      expect(const Discount.none().isNone, isTrue);
    });

    test('percent rounds once, half away from zero', () {
      // 12.5% of 0.03 = 0.00375 -> 0.00 ; 10% of 0.05 = 0.005 -> 0.01
      expect(Discount.percent(1250).appliedTo(inr(3)), inr(0));
      expect(Discount.percent(1000).appliedTo(inr(5)), inr(1));
      expect(Discount.percent(10000).appliedTo(inr(12345)), inr(12345));
    });

    test('amount is taken as given', () {
      expect(Discount.amount(inr(250)).appliedTo(inr(1000)), inr(250));
    });

    test('rejects invalid values', () {
      expect(() => Discount.percent(-1), throwsArgumentError);
      expect(() => Discount.percent(10001), throwsArgumentError);
      expect(() => Discount.amount(inr(-1)), throwsArgumentError);
    });

    test('stores and restores', () {
      Money money(int minor) => inr(minor);
      for (final d in [
        const Discount.none(),
        Discount.percent(750),
        Discount.amount(inr(99)),
      ]) {
        expect(Discount.fromStored(d.kind, d.storedValue, money: money), d);
      }
    });
  });

  group('DocumentNumber', () {
    test('pads and grows', () {
      expect(DocumentNumber.format('PUR-', 1), 'PUR-000001');
      expect(DocumentNumber.format('PUR-', 42), 'PUR-000042');
      expect(DocumentNumber.format('PUR-', 1234567), 'PUR-1234567');
      expect(() => DocumentNumber.format('PUR-', 0), throwsArgumentError);
    });
  });
}
