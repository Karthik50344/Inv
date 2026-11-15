import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// An expense as shown in a list.
final class ExpenseSummary extends Equatable {
  /// Creates a summary.
  const ExpenseSummary({
    required this.id,
    required this.status,
    required this.expenseDate,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.methodName,
    required this.total,
    this.number,
    this.payee,
  });

  /// Expense id.
  final String id;

  /// Document number once posted.
  final String? number;

  /// Lifecycle status.
  final DocumentStatus status;

  /// Day the expense was incurred.
  final DateTime expenseDate;

  /// Category id.
  final String categoryId;

  /// Category name snapshot.
  final String categoryName;

  /// What it was for.
  final String description;

  /// Who was paid.
  final String? payee;

  /// Payment method name snapshot.
  final String methodName;

  /// Total including tax.
  final Money total;

  /// Number, or "Draft" before posting.
  String get displayNumber => number ?? 'Draft';

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
    methodName,
    total,
  ];
}
