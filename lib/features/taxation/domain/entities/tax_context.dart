import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';

/// The business-level facts every tax calculation needs.
final class TaxContext {
  /// Creates a context.
  const TaxContext({
    required this.taxProfileId,
    required this.sellerLocation,
    this.isSellerTaxRegistered = true,
  });

  /// The default, active tax profile.
  final String taxProfileId;

  /// Where the business is. The place of supply is taken to be the same
  /// until customer locations are recorded.
  final TaxLocation sellerLocation;

  /// Whether the business is registered for the tax (setting
  /// `tax_seller_registered`, default yes).
  final bool isSellerTaxRegistered;
}
