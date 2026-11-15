import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Raw (text) input for a customer or supplier form.
final class PartyDraft extends Equatable {
  /// Creates a draft.
  const PartyDraft({
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.taxId = '',
    this.notes = '',
    this.openingBalance = '',
  });

  /// Name text.
  final String name;

  /// Phone text.
  final String phone;

  /// E-mail text.
  final String email;

  /// Street address text.
  final String address;

  /// City text.
  final String city;

  /// State/region text.
  final String state;

  /// Postal code text.
  final String postalCode;

  /// Tax identification number text.
  final String taxId;

  /// Free-form notes.
  final String notes;

  /// Opening balance text (blank = 0; negative means a credit).
  final String openingBalance;

  @override
  List<Object?> get props => [
    name,
    phone,
    email,
    address,
    city,
    state,
    postalCode,
    taxId,
    notes,
    openingBalance,
  ];
}

/// Validated, typed customer/supplier data.
final class PartyFields extends Equatable {
  /// Creates validated fields.
  const PartyFields({
    required this.name,
    required this.openingBalance,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.taxId,
    this.notes,
  });

  /// Trimmed name.
  final String name;

  /// Phone number.
  final String? phone;

  /// E-mail address.
  final String? email;

  /// Street address.
  final String? address;

  /// City.
  final String? city;

  /// State/region.
  final String? state;

  /// Postal code.
  final String? postalCode;

  /// Tax identification number.
  final String? taxId;

  /// Notes.
  final String? notes;

  /// Opening balance (signed).
  final Money openingBalance;

  @override
  List<Object?> get props => [
    name,
    phone,
    email,
    address,
    city,
    state,
    postalCode,
    taxId,
    notes,
    openingBalance,
  ];
}

/// Validates [draft] and converts it into [PartyFields].
Result<PartyFields> validatePartyDraft(
  PartyDraft draft,
  CurrencyConfig currency,
) {
  final errors = FieldErrors()
    ..add('name', Validators.requiredText(draft.name, label: 'Name'))
    ..add('phone', Validators.optionalPhone(draft.phone))
    ..add('email', Validators.optionalEmail(draft.email))
    ..add(
      'address',
      Validators.optionalText(draft.address, label: 'Address', maxLength: 300),
    )
    ..add(
      'city',
      Validators.optionalText(draft.city, label: 'City', maxLength: 80),
    )
    ..add(
      'state',
      Validators.optionalText(draft.state, label: 'State', maxLength: 80),
    )
    ..add(
      'postalCode',
      Validators.optionalText(
        draft.postalCode,
        label: 'Postal code',
        maxLength: 20,
      ),
    )
    ..add(
      'taxId',
      Validators.optionalText(draft.taxId, label: 'Tax ID', maxLength: 40),
    )
    ..add(
      'notes',
      Validators.optionalText(draft.notes, label: 'Notes', maxLength: 500),
    );

  var opening = currency.zero();
  if (draft.openingBalance.trim().isNotEmpty) {
    final parsed = currency.parse(draft.openingBalance);
    if (parsed == null) {
      errors.add(
        'openingBalance',
        'Opening balance must be a number with up to '
            '${currency.decimalPlaces} decimal places.',
      );
    } else {
      opening = parsed;
    }
  }
  if (!errors.isEmpty) {
    return Result.failure(errors.toFailure());
  }
  return Result.success(
    PartyFields(
      name: draft.name.trim(),
      phone: blankToNull(draft.phone),
      email: blankToNull(draft.email),
      address: blankToNull(draft.address),
      city: blankToNull(draft.city),
      state: blankToNull(draft.state),
      postalCode: blankToNull(draft.postalCode),
      taxId: blankToNull(draft.taxId),
      notes: blankToNull(draft.notes),
      openingBalance: opening,
    ),
  );
}
