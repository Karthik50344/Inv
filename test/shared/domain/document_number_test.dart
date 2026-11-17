import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';

void main() {
  group('DocumentNumber.format', () {
    test('pads to the configured width and grows beyond it', () {
      expect(DocumentNumber.format('INV-', 7), 'INV-000007');
      expect(DocumentNumber.format('INV-', 7, padding: 4), 'INV-0007');
      expect(DocumentNumber.format('INV-', 1234567, padding: 4), 'INV-1234567');
      expect(() => DocumentNumber.format('INV-', 0), throwsArgumentError);
    });
  });

  group('DocumentNumber.validatePrefix', () {
    test('accepts letters, digits and separators that end in a non-digit', () {
      for (final ok in ['INV-', 'A', 'S2-', 'shop/inv-', 'INV_', 'a.b.']) {
        expect(DocumentNumber.validatePrefix(ok), isNull, reason: ok);
      }
    });

    test('rejects empty, long, odd characters and a trailing digit', () {
      expect(DocumentNumber.validatePrefix(''), isNotNull);
      expect(DocumentNumber.validatePrefix('ABCDEFGHIJK'), isNotNull);
      expect(DocumentNumber.validatePrefix('IN V-'), isNotNull);
      expect(DocumentNumber.validatePrefix('INV#'), isNotNull);
      expect(DocumentNumber.validatePrefix('INV2'), isNotNull);
    });

    test('with valid prefixes no two (prefix, counter) pairs collide', () {
      final prefixes = ['A-', 'A', 'AB', 'A-B', 'A--'];
      final seen = <String, String>{};
      for (final prefix in prefixes) {
        expect(DocumentNumber.validatePrefix(prefix), isNull);
        for (var n = 1; n <= 2000; n += 7) {
          final text = DocumentNumber.format(prefix, n, padding: 3);
          final who = '$prefix#$n';
          expect(seen[text] ?? who, who, reason: text);
          seen[text] = who;
        }
      }
    });
  });

  test('padding limits', () {
    expect(DocumentNumber.validatePadding(2), isNotNull);
    expect(DocumentNumber.validatePadding(3), isNull);
    expect(DocumentNumber.validatePadding(10), isNull);
    expect(DocumentNumber.validatePadding(11), isNotNull);
  });

  test('document kinds keep the counter keys already stored on devices', () {
    expect(
      {for (final k in DocumentKind.values) k.sequenceKey: k.defaultPrefix},
      {
        'sales_invoice': 'INV-',
        'purchase_invoice': 'PUR-',
        'payment': 'PAY-',
        'refund': 'RFD-',
        'sales_return': 'SRN-',
        'purchase_return': 'PRN-',
        'expense': 'EXP-',
      },
    );
    expect(
      DocumentKind.salesInvoice.prefixSettingKey,
      'numbering.prefix.sales_invoice',
    );
  });
}
