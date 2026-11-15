import 'package:equatable/equatable.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_amounts.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Where expense numbers and audit records come from.
abstract final class ExpenseNumbering {
  /// Key of the document sequence.
  static const String sequenceKey = 'expense';

  /// Prefix of the formatted number (configurable in Phase 11).
  static const String prefix = 'EXP-';

  /// Audit source type for expenses.
  static const String sourceType = 'expense';
}

/// A business expense: what was bought, when, how it was paid and what it
/// cost.
///
/// Lifecycle: a [DocumentStatus.draft] can be edited, posted or cancelled.
/// A [DocumentStatus.posted] expense counts in the reports and is never
/// edited; it can only be voided with a reason. Expenses do not touch
/// inventory. Category, payment method and tax name are snapshots.
final class Expense extends Equatable {
  /// Creates an expense.
  const Expense({
    required this.id,
    required this.status,
    required this.expenseDate,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.methodId,
    required this.methodName,
    required this.amountIncludesTax,
    required this.taxRateBp,
    required this.amounts,
    required this.createdAt,
    required this.updatedAt,
    this.number,
    this.payee,
    this.reference,
    this.notes,
    this.taxRateId,
    this.taxName,
    this.attachments = const [],
    this.postedAt,
    this.cancelledAt,
    this.voidedAt,
    this.voidReason,
  });

  /// Unique id.
  final String id;

  /// Document number, assigned when posted; `null` before.
  final String? number;

  /// Lifecycle status.
  final DocumentStatus status;

  /// The day the expense was incurred (UTC midnight of the chosen day).
  final DateTime expenseDate;

  /// Category id.
  final String categoryId;

  /// Category name at the time of saving (posting refreshes it).
  final String categoryName;

  /// What the expense was for.
  final String description;

  /// Who was paid, if recorded.
  final String? payee;

  /// Payment method id.
  final String methodId;

  /// Payment method name snapshot.
  final String methodName;

  /// Receipt number or other external reference.
  final String? reference;

  /// Free-text notes.
  final String? notes;

  /// Whether the entered amount included tax.
  final bool amountIncludesTax;

  /// Chosen tax rate id, if any.
  final String? taxRateId;

  /// Tax name snapshot.
  final String? taxName;

  /// Tax rate in basis points (0 when none or exempt).
  final int taxRateBp;

  /// Net, tax and total.
  final ExpenseAmounts amounts;

  /// Attached receipts, oldest first.
  final List<ExpenseAttachment> attachments;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// When it was posted.
  final DateTime? postedAt;

  /// When the draft was cancelled.
  final DateTime? cancelledAt;

  /// When it was voided (after posting).
  final DateTime? voidedAt;

  /// Why it was voided.
  final String? voidReason;

  /// Text to show for the document: its number, or "Draft".
  String get displayNumber => number ?? 'Draft';

  /// Whether the content may still be edited.
  bool get isEditable => status.isEditable;

  @override
  List<Object?> get props => [
    id,
    number,
    status,
    expenseDate,
    categoryId,
    categoryName,
    description,
    payee,
    methodId,
    methodName,
    reference,
    notes,
    amountIncludesTax,
    taxRateId,
    taxName,
    taxRateBp,
    amounts,
    attachments,
    createdAt,
    updatedAt,
    postedAt,
    cancelledAt,
    voidedAt,
    voidReason,
  ];
}
