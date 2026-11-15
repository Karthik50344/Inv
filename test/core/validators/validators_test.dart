import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';

void main() {
  group('Validators', () {
    test('requiredText', () {
      expect(Validators.requiredText('  ', label: 'Name'), 'Name is required.');
      expect(Validators.requiredText(null, label: 'Name'), isNotNull);
      expect(Validators.requiredText('ok', label: 'Name'), isNull);
      expect(
        Validators.requiredText('x' * 11, label: 'Name', maxLength: 10),
        isNotNull,
      );
    });

    test('optionalText', () {
      expect(Validators.optionalText(null, label: 'Notes'), isNull);
      expect(
        Validators.optionalText('x' * 6, label: 'Notes', maxLength: 5),
        isNotNull,
      );
    });

    test('optionalEmail', () {
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail('a@b.co'), isNull);
      expect(Validators.optionalEmail('a@b'), isNotNull);
      expect(Validators.optionalEmail('a b@c.com'), isNotNull);
    });

    test('optionalPhone', () {
      expect(Validators.optionalPhone(''), isNull);
      expect(Validators.optionalPhone('+91 98765-43210'), isNull);
      expect(Validators.optionalPhone('(044) 2345 6789'), isNull);
      expect(Validators.optionalPhone('12345'), isNotNull);
      expect(Validators.optionalPhone('abc123456'), isNotNull);
      expect(Validators.optionalPhone('1' * 16), isNotNull);
    });

    test('blankToNull trims and nulls blanks', () {
      expect(blankToNull('  hi '), 'hi');
      expect(blankToNull('   '), isNull);
      expect(blankToNull(null), isNull);
    });
  });

  group('FieldErrors', () {
    test('keeps the first message per field and ignores nulls', () {
      final errors = FieldErrors()
        ..add('a', null)
        ..add('b', 'first')
        ..add('b', 'second');
      expect(errors.isEmpty, isFalse);
      expect(errors.toFailure().fieldErrors['b'], 'first');
      expect(errors.toFailure().fieldErrors.containsKey('a'), isFalse);
      expect(FieldErrors().isEmpty, isTrue);
    });
  });
}
