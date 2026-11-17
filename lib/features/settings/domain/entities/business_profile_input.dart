import 'package:equatable/equatable.dart';

/// Raw text from the business profile form.
final class BusinessProfileInput extends Equatable {
  /// Creates an input.
  const BusinessProfileInput({
    required this.name,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.taxId = '',
    this.logoPath,
  });

  /// Business name (required).
  final String name;

  /// Postal address, may span several lines.
  final String address;

  /// Phone number.
  final String phone;

  /// E-mail address.
  final String email;

  /// Tax registration number.
  final String taxId;

  /// Stored (relative) path of the logo, if one is chosen.
  final String? logoPath;

  @override
  List<Object?> get props => [name, address, phone, email, taxId, logoPath];
}
