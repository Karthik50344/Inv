import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/product_classification/domain/services/classification_validator.dart';

void main() {
  final now = DateTime.utc(2026, 6, 1);

  ProductClassification? ok({
    String system = 'hsn',
    String code = '8471',
    ClassificationType type = ClassificationType.goods,
    String description = '',
    String country = '',
  }) => ClassificationValidator.build(
    id: 'c1',
    productId: 'p1',
    systemText: system,
    codeText: code,
    type: type,
    isPrimary: false,
    now: now,
    descriptionText: description,
    countryText: country,
  ).valueOrNull;

  Map<String, String> errors({
    String system = 'hsn',
    String code = '8471',
    ClassificationType type = ClassificationType.goods,
    String description = '',
    String country = '',
  }) {
    final r = ClassificationValidator.build(
      id: 'c1',
      productId: 'p1',
      systemText: system,
      codeText: code,
      type: type,
      isPrimary: false,
      now: now,
      descriptionText: description,
      countryText: country,
    );
    return (r.failureOrNull! as ValidationFailure).fieldErrors;
  }

  group('HSN', () {
    test('accepts 2, 4, 6 and 8 digits and strips separators', () {
      for (final code in ['84', '8471', '847130', '84713010', '8471 30.10']) {
        expect(ok(code: code), isNotNull, reason: code);
      }
      expect(ok(code: '8471.30')!.code, '847130');
    });

    test('rejects other lengths and non-digits', () {
      for (final code in ['8', '847', '84713', '847130101', 'ABCD']) {
        expect(errors(code: code).containsKey('code'), isTrue, reason: code);
      }
    });

    test('is for goods', () {
      expect(errors(type: ClassificationType.services)['type'], isNotNull);
    });
  });

  group('SAC', () {
    test('needs exactly 6 digits and services', () {
      expect(
        ok(system: 'sac', code: '998314', type: ClassificationType.services),
        isNotNull,
      );
      expect(
        errors(system: 'sac', code: '9983', type: ClassificationType.services)['code'],
        isNotNull,
      );
      expect(
        errors(system: 'sac', code: '998314')['type'],
        isNotNull,
      );
    });
  });

  group('HS and custom systems', () {
    test('HS accepts even lengths from 2 to 12', () {
      for (final code in ['85', '8517', '851712', '85171200', '8517120000']) {
        expect(ok(system: 'hs', code: code), isNotNull, reason: code);
      }
      expect(errors(system: 'hs', code: '85171')['code'], isNotNull);
    });

    test('a custom system takes a free-form code, upper-cased', () {
      final c = ok(
        system: 'TARIC',
        code: 'ab 12.3/4',
        type: ClassificationType.other,
      )!;
      expect(c.system, const ClassificationSystem('taric'));
      expect(c.code, 'AB 12.3/4');
    });

    test('a custom code with odd characters is rejected', () {
      expect(
        errors(system: 'taric', code: 'ab;12', type: ClassificationType.other)['code'],
        isNotNull,
      );
    });

    test('a system name with spaces becomes a dashed code', () {
      expect(
        ok(system: 'My System', code: 'X1', type: ClassificationType.other)!.system.code,
        'my-system',
      );
    });
  });

  test('required fields are reported together', () {
    final e = errors(system: '', code: '');
    expect(e.keys, containsAll(['system', 'code']));
  });

  test('country must be two letters and is upper-cased', () {
    expect(errors(country: 'IND')['country'], isNotNull);
    expect(ok(country: 'in')!.countryCode, 'IN');
    expect(ok()!.countryCode, isNull);
  });

  test('description is trimmed, optional and limited', () {
    expect(ok(description: '  Computers ')!.description, 'Computers');
    expect(ok()!.description, isNull);
    expect(errors(description: 'x' * 201)['description'], isNotNull);
  });

  test('timestamps and primary flag are carried through', () {
    final c = ok()!;
    expect(c.createdAt, now);
    expect(c.updatedAt, now);
    expect(c.isPrimary, isFalse);
  });

  test('the snapshot label reads HSN 8471', () {
    expect(const ClassificationSnapshot(system: 'hsn', code: '8471').label, 'HSN 8471');
  });
}
