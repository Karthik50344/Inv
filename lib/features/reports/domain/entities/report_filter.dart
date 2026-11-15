import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';

/// Criteria of a report. Which fields apply depends on the report (see
/// `ReportKind`); the others are ignored.
final class ReportFilter extends Equatable {
  /// Creates a filter.
  const ReportFilter({
    required this.range,
    this.productId,
    this.customerId,
    this.supplierId,
  });

  /// The days covered.
  final DateRange range;

  /// Restrict to one product.
  final String? productId;

  /// Restrict to one customer.
  final String? customerId;

  /// Restrict to one supplier.
  final String? supplierId;

  /// Copy with changes. The `clear*` flags reset an id to `null`.
  ReportFilter copyWith({
    DateRange? range,
    String? productId,
    bool clearProduct = false,
    String? customerId,
    bool clearCustomer = false,
    String? supplierId,
    bool clearSupplier = false,
  }) => ReportFilter(
    range: range ?? this.range,
    productId: clearProduct ? null : (productId ?? this.productId),
    customerId: clearCustomer ? null : (customerId ?? this.customerId),
    supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
  );

  @override
  List<Object?> get props => [range, productId, customerId, supplierId];
}
