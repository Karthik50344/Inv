import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';

/// Raw (text) input for one purchase line, as typed by the user.
final class PurchaseLineInput extends Equatable {
  /// Creates a line input.
  const PurchaseLineInput({
    required this.productId,
    required this.quantity,
    this.unitPrice = '',
    this.discountKind = DiscountKind.none,
    this.discountValue = '',
  });

  /// The product to purchase.
  final String productId;

  /// Quantity text, within the unit's precision.
  final String quantity;

  /// Unit price text; blank uses the product's purchase price.
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

/// Raw input for saving a purchase draft.
final class PurchaseDraftInput extends Equatable {
  /// Creates a draft input. Pass [id] to edit an existing draft.
  const PurchaseDraftInput({
    required this.supplierId,
    required this.invoiceDate,
    required this.lines,
    this.id,
    this.dueDate,
    this.supplierReference = '',
    this.notes = '',
  });

  /// Id of the draft being edited; `null` creates a new draft.
  final String? id;

  /// Chosen supplier.
  final String supplierId;

  /// Invoice date.
  final DateTime? invoiceDate;

  /// Optional due date.
  final DateTime? dueDate;

  /// The supplier's own invoice number.
  final String supplierReference;

  /// Free-text notes.
  final String notes;

  /// Line inputs.
  final List<PurchaseLineInput> lines;

  @override
  List<Object?> get props => [
    id,
    supplierId,
    invoiceDate,
    dueDate,
    supplierReference,
    notes,
    lines,
  ];
}
