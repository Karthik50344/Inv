import 'package:equatable/equatable.dart';

/// Raw (text) input for saving an expense draft, as typed by the user.
final class ExpenseDraftInput extends Equatable {
  /// Creates a draft input. Pass [id] to edit an existing draft.
  const ExpenseDraftInput({
    required this.categoryId,
    required this.expenseDate,
    required this.description,
    required this.amount,
    required this.methodId,
    this.id,
    this.payee = '',
    this.amountIncludesTax = false,
    this.taxRateId,
    this.reference = '',
    this.notes = '',
  });

  /// Id of the draft being edited; `null` creates a new draft.
  final String? id;

  /// Chosen category.
  final String categoryId;

  /// Day the expense was incurred.
  final DateTime? expenseDate;

  /// What the expense was for.
  final String description;

  /// Who was paid.
  final String payee;

  /// Amount text, within the currency's decimal places.
  final String amount;

  /// Whether [amount] already includes tax.
  final bool amountIncludesTax;

  /// Chosen tax rate id, or `null` when no tax applies.
  final String? taxRateId;

  /// Chosen payment method.
  final String methodId;

  /// Receipt number or other reference.
  final String reference;

  /// Free-text notes.
  final String notes;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    expenseDate,
    description,
    payee,
    amount,
    amountIncludesTax,
    taxRateId,
    methodId,
    reference,
    notes,
  ];
}
