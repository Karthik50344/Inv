import 'package:equatable/equatable.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Whether the form's reference data (and product, when editing) is ready.
enum FormLoadStatus { loading, ready, notFound, failure }

/// State of the product form.
final class ProductFormState extends Equatable {
  /// Creates a state.
  const ProductFormState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.product,
    this.categories = const [],
    this.units = const [],
    this.taxRates = const [],
    this.currency,
    this.imagePath,
    this.fieldErrors = const {},
    this.message,
    this.savedProductId,
  });

  /// Load status.
  final FormLoadStatus loadStatus;

  /// Submission status.
  final SubmitStatus submitStatus;

  /// The product being edited, `null` when creating.
  final Product? product;

  /// Selectable categories.
  final List<Category> categories;

  /// Selectable units.
  final List<UnitOfMeasure> units;

  /// Selectable tax rates.
  final List<TaxRate> taxRates;

  /// Active currency (for labels and hints).
  final CurrencyConfig? currency;

  /// Stored (relative) image path.
  final String? imagePath;

  /// Per-field validation messages from the last submit.
  final Map<String, String> fieldErrors;

  /// One-shot user-facing message.
  final String? message;

  /// Id of the product that was just saved.
  final String? savedProductId;

  /// Whether an existing product is being edited.
  bool get isEditing => product != null;

  /// Copy with changes. [fieldErrors], [message] and [savedProductId] reset
  /// unless provided; use [clearImage] to drop the image.
  ProductFormState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    Product? product,
    List<Category>? categories,
    List<UnitOfMeasure>? units,
    List<TaxRate>? taxRates,
    CurrencyConfig? currency,
    String? imagePath,
    bool clearImage = false,
    Map<String, String>? fieldErrors,
    String? message,
    String? savedProductId,
  }) => ProductFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    product: product ?? this.product,
    categories: categories ?? this.categories,
    units: units ?? this.units,
    taxRates: taxRates ?? this.taxRates,
    currency: currency ?? this.currency,
    imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    fieldErrors: fieldErrors ?? const {},
    message: message,
    savedProductId: savedProductId,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    product,
    categories,
    units,
    taxRates,
    currency,
    imagePath,
    fieldErrors,
    message,
    savedProductId,
  ];
}
