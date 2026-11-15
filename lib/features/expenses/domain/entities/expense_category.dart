import 'package:equatable/equatable.dart';

/// A category that expenses are filed under (rent, utilities, ...).
///
/// Separate from product categories. Archived instead of deleted: posted
/// expenses keep a snapshot of the name anyway.
final class ExpenseCategory extends Equatable {
  /// Creates a category.
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.archivedAt,
  });

  /// Unique id.
  final String id;

  /// Display name (unique among active categories, case-insensitive).
  final String name;

  /// Optional description.
  final String? description;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// Archive time, if archived.
  final DateTime? archivedAt;

  /// Whether the category can no longer be chosen for new expenses.
  bool get isArchived => archivedAt != null;

  /// Copy with new details.
  ExpenseCategory withDetails({
    required String name,
    required DateTime updatedAt,
    String? description,
  }) => ExpenseCategory(
    id: id,
    name: name,
    description: description,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  /// Archived copy.
  ExpenseCategory archived(DateTime at) => ExpenseCategory(
    id: id,
    name: name,
    description: description,
    createdAt: createdAt,
    updatedAt: at,
    archivedAt: at,
  );

  /// Restored (active) copy.
  ExpenseCategory restored(DateTime at) => ExpenseCategory(
    id: id,
    name: name,
    description: description,
    createdAt: createdAt,
    updatedAt: at,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    createdAt,
    updatedAt,
    archivedAt,
  ];
}
