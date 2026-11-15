import 'package:equatable/equatable.dart';

/// A product category. Archived instead of deleted.
final class Category extends Equatable {
  /// Creates a category.
  const Category({
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

  /// Whether the category is archived.
  bool get isArchived => archivedAt != null;

  /// Copy with new details.
  Category withDetails({
    required String name,
    required DateTime updatedAt,
    String? description,
  }) => Category(
    id: id,
    name: name,
    description: description,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  /// Archived copy.
  Category archived(DateTime at) => Category(
    id: id,
    name: name,
    description: description,
    createdAt: createdAt,
    updatedAt: at,
    archivedAt: at,
  );

  /// Restored (active) copy.
  Category restored(DateTime at) => Category(
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
