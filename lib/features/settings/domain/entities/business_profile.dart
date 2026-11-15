import 'package:equatable/equatable.dart';

/// The business identity printed on invoices.
final class BusinessProfile extends Equatable {
  /// Creates a profile.
  const BusinessProfile({
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.taxId,
    this.logoPath,
  });

  /// Used until the owner enters the business details.
  static const BusinessProfile placeholder = BusinessProfile(
    name: 'My Business',
  );

  /// Business name.
  final String name;

  /// Postal address (free text, may span several lines).
  final String? address;

  /// Phone number.
  final String? phone;

  /// E-mail address.
  final String? email;

  /// Tax registration number.
  final String? taxId;

  /// Path of the logo image, relative to the application documents folder.
  final String? logoPath;

  @override
  List<Object?> get props => [name, address, phone, email, taxId, logoPath];
}
