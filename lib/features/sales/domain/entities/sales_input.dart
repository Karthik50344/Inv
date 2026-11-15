import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';

/// Raw (text) input for one sale line, as typed by the user.
final class SalesLineInput extends Equatable {
  /// Creates a line input.
  const SalesLineInput({
    required this.productId,
    required this.quantity,
    this.unitPrice = '',
    this.discountKind = DiscountKind.none,
    this.discountValue = '',
  });

  /// The product to sale.
  final String productId;

  /// Quantity text, within the unit's precision.
  final String quantity;

  /// Unit price text; blank uses the product's sale price.
  final String unitPrice;

  /// How the discount is expressed.
  final DiscountKind discountKind;

  /// Discount text: a percentage (up to 2 decimals) for
  /// [DiscountKind.percent], a money amount for [DiscountKind.amount].
  final String discountValue;

  @override
  List<Object?> get props => [
    productId,
    quantity,
    unitPrice,
    discountKind,
    discountValue,
  ];
}

/// Raw input for saving a sale draft.
final class SalesDraftInput extends Equatable {
  /// Creates a draft input. Pass [id] to edit an existing draft.
  const SalesDraftInput({
    this.customerId,
    required this.invoiceDate,
    required this.lines,
    this.id,
    this.dueDate,
    this.customerReference = '',
    this.notes = '',
  });

  /// Id of the draft being edited; `null` creates a new draft.
  final String? id;

  /// Chosen customer; `null` records a walk-in sale.
  final String? customerId;

  /// Invoice date.
  final DateTime? invoiceDate;

  /// Optional due date.
  final DateTime? dueDate;

  /// The customer's own reference (for example their order number).
  final String customerReference;

  /// Free-text notes.
  final String notes;

  /// Line inputs.
  final List<SalesLineInput> lines;

  @override
  List<Object?> get props => [
    id,
    customerId,
    invoiceDate,
    dueDate,
    customerReference,
    notes,
    lines,
  ];
}
