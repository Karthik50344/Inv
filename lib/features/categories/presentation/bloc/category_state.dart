import 'package:equatable/equatable.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the categories screen.
final class CategoryState extends Equatable {
  /// Creates a state.
  const CategoryState({
    this.status = ViewStatus.initial,
    this.categories = const [],
    this.query = '',
    this.includeArchived = false,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded categories.
  final List<Category> categories;

  /// Current search text.
  final String query;

  /// Whether archived categories are shown.
  final bool includeArchived;

  /// One-shot user-facing message (error from the last action).
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  CategoryState copyWith({
    ViewStatus? status,
    List<Category>? categories,
    String? query,
    bool? includeArchived,
    String? message,
  }) => CategoryState(
    status: status ?? this.status,
    categories: categories ?? this.categories,
    query: query ?? this.query,
    includeArchived: includeArchived ?? this.includeArchived,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    categories,
    query,
    includeArchived,
    message,
  ];
}
