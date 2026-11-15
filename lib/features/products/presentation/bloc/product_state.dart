import 'package:equatable/equatable.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the product list.
final class ProductState extends Equatable {
  /// Creates a state.
  const ProductState({
    this.status = ViewStatus.initial,
    this.products = const [],
    this.filter = const ProductFilter(),
    this.categories = const [],
    this.units = const {},
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded products.
  final List<Product> products;

  /// Active filter.
  final ProductFilter filter;

  /// Active categories for the filter chips.
  final List<Category> categories;

  /// Units by id (including archived) for symbol lookup.
  final Map<String, UnitOfMeasure> units;

  /// One-shot user-facing message.
  final String? message;

  /// Whether any filter narrows the list.
  bool get isFiltered =>
      filter.query.isNotEmpty ||
      filter.categoryId != null ||
      filter.includeArchived;

  /// Copy with changes; [message] is cleared unless provided.
  ProductState copyWith({
    ViewStatus? status,
    List<Product>? products,
    ProductFilter? filter,
    List<Category>? categories,
    Map<String, UnitOfMeasure>? units,
    String? message,
  }) => ProductState(
    status: status ?? this.status,
    products: products ?? this.products,
    filter: filter ?? this.filter,
    categories: categories ?? this.categories,
    units: units ?? this.units,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    products,
    filter,
    categories,
    units,
    message,
  ];
}
