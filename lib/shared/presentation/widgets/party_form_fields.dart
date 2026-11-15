import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';

/// Text controllers for a customer/supplier form.
class PartyFormControllers {
  /// Creates empty controllers.
  PartyFormControllers()
    : name = TextEditingController(),
      phone = TextEditingController(),
      email = TextEditingController(),
      address = TextEditingController(),
      city = TextEditingController(),
      state = TextEditingController(),
      postalCode = TextEditingController(),
      taxId = TextEditingController(),
      notes = TextEditingController(),
      openingBalance = TextEditingController();

  /// Name input.
  final TextEditingController name;

  /// Phone input.
  final TextEditingController phone;

  /// E-mail input.
  final TextEditingController email;

  /// Address input.
  final TextEditingController address;

  /// City input.
  final TextEditingController city;

  /// State input.
  final TextEditingController state;

  /// Postal code input.
  final TextEditingController postalCode;

  /// Tax ID input.
  final TextEditingController taxId;

  /// Notes input.
  final TextEditingController notes;

  /// Opening balance input.
  final TextEditingController openingBalance;

  /// Fills the controllers from existing values.
  void fill({
    required String name,
    required String openingBalance,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    String? taxId,
    String? notes,
  }) {
    this.name.text = name;
    this.openingBalance.text = openingBalance;
    this.phone.text = phone ?? '';
    this.email.text = email ?? '';
    this.address.text = address ?? '';
    this.city.text = city ?? '';
    this.state.text = state ?? '';
    this.postalCode.text = postalCode ?? '';
    this.taxId.text = taxId ?? '';
    this.notes.text = notes ?? '';
  }

  /// Builds a draft from the current text.
  PartyDraft toDraft() => PartyDraft(
    name: name.text,
    phone: phone.text,
    email: email.text,
    address: address.text,
    city: city.text,
    state: state.text,
    postalCode: postalCode.text,
    taxId: taxId.text,
    notes: notes.text,
    openingBalance: openingBalance.text,
  );

  /// Releases all controllers.
  void dispose() {
    for (final controller in [
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
    ]) {
      controller.dispose();
    }
  }
}

/// The input fields shared by the customer and supplier forms.
class PartyFormFields extends StatelessWidget {
  /// Creates the fields.
  const PartyFormFields({
    required this.controllers,
    required this.fieldErrors,
    required this.currencyCode,
    required this.openingBalanceHint,
    super.key,
  });

  /// Controllers holding the text.
  final PartyFormControllers controllers;

  /// Server-side validation messages by field name.
  final Map<String, String> fieldErrors;

  /// Currency shown next to the opening balance.
  final String currencyCode;

  /// Helper text explaining what a positive opening balance means.
  final String openingBalanceHint;

  @override
  Widget build(BuildContext context) {
    Widget field(
      String key,
      TextEditingController controller,
      String label, {
      TextInputType? keyboardType,
      int maxLines = 1,
      bool required = false,
      String? helperText,
      String? prefixText,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: TextFormField(
        key: Key('party_$key'),
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textInputAction: maxLines == 1
            ? TextInputAction.next
            : TextInputAction.newline,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          helperText: helperText,
          prefixText: prefixText,
          errorText: fieldErrors[key],
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) => (value == null || value.trim().isEmpty)
                  ? '$label is required.'
                  : null
            : null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field('name', controllers.name, 'Name', required: true),
        field(
          'phone',
          controllers.phone,
          'Phone',
          keyboardType: TextInputType.phone,
        ),
        field(
          'email',
          controllers.email,
          'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        field('address', controllers.address, 'Address', maxLines: 2),
        field('city', controllers.city, 'City'),
        field('state', controllers.state, 'State'),
        field(
          'postalCode',
          controllers.postalCode,
          'Postal code',
          keyboardType: TextInputType.text,
        ),
        field('taxId', controllers.taxId, 'Tax ID'),
        field(
          'openingBalance',
          controllers.openingBalance,
          'Opening balance',
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          helperText: openingBalanceHint,
          prefixText: '$currencyCode ',
        ),
        field('notes', controllers.notes, 'Notes', maxLines: 3),
      ],
    );
  }
}
