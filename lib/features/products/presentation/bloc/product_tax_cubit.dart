import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/product_classification/domain/repositories/product_classification_repository.dart';
import 'package:inventrix/features/product_classification/domain/usecases/classification_use_cases.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/usecases/set_product_tax_treatment.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';
import 'package:inventrix/features/taxation/domain/services/product_tax_classifier.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the product "Tax and classification" screen.
final class ProductTaxState extends Equatable {
  /// Creates the state.
  const ProductTaxState({
    this.status = ViewStatus.initial,
    this.product,
    this.categories = const [],
    this.overrides = const [],
    this.effective,
    this.effectiveCategory,
    this.hasProfile = false,
    this.classifications = const [],
    this.suggestions = const [],
    this.busy = false,
    this.message,
    this.messageSerial = 0,
    this.error,
  });

  /// Loading state.
  final ViewStatus status;

  /// The product.
  final Product? product;

  /// Active categories to choose from.
  final List<TaxCategory> categories;

  /// Active overrides to choose from.
  final List<TaxOverride> overrides;

  /// Where the effective category comes from, when it can be resolved.
  final EffectiveTaxCategory? effective;

  /// The effective category.
  final TaxCategory? effectiveCategory;

  /// Whether a default tax profile exists.
  final bool hasProfile;

  /// The product's classifications, primary first.
  final List<ProductClassification> classifications;

  /// Codes already used elsewhere that match the search box.
  final List<ClassificationSuggestion> suggestions;

  /// Whether a change is being saved.
  final bool busy;

  /// A short result message.
  final String? message;

  /// Changes with every message.
  final int messageSerial;

  /// A readable load error.
  final String? error;

  /// Copy with changes.
  ProductTaxState copyWith({
    ViewStatus? status,
    Product? product,
    List<TaxCategory>? categories,
    List<TaxOverride>? overrides,
    EffectiveTaxCategory? effective,
    bool clearEffective = false,
    TaxCategory? effectiveCategory,
    bool? hasProfile,
    List<ProductClassification>? classifications,
    List<ClassificationSuggestion>? suggestions,
    bool? busy,
    String? message,
    String? error,
  }) => ProductTaxState(
    status: status ?? this.status,
    product: product ?? this.product,
    categories: categories ?? this.categories,
    overrides: overrides ?? this.overrides,
    effective: clearEffective ? null : effective ?? this.effective,
    effectiveCategory: clearEffective ? null : effectiveCategory ?? this.effectiveCategory,
    hasProfile: hasProfile ?? this.hasProfile,
    classifications: classifications ?? this.classifications,
    suggestions: suggestions ?? this.suggestions,
    busy: busy ?? this.busy,
    message: message,
    messageSerial: message == null ? messageSerial : messageSerial + 1,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    product,
    categories,
    overrides,
    effective,
    effectiveCategory,
    hasProfile,
    classifications,
    suggestions,
    busy,
    message,
    messageSerial,
    error,
  ];
}

/// Tax category, override and classification of one product.
class ProductTaxCubit extends Cubit<ProductTaxState> {
  /// Creates the cubit.
  ProductTaxCubit({
    required ProductRepository products,
    required TaxRepository tax,
    required ProductClassificationRepository classifications,
    required SetProductTaxTreatment setTreatment,
    required AddProductClassification add,
    required UpdateProductClassification update,
    required RemoveProductClassification remove,
    required SetPrimaryProductClassification setPrimary,
  }) : _products = products,
       _tax = tax,
       _classifications = classifications,
       _setTreatment = setTreatment,
       _add = add,
       _update = update,
       _remove = remove,
       _setPrimary = setPrimary,
       super(const ProductTaxState());

  final ProductRepository _products;
  final TaxRepository _tax;
  final ProductClassificationRepository _classifications;
  final SetProductTaxTreatment _setTreatment;
  final AddProductClassification _add;
  final UpdateProductClassification _update;
  final RemoveProductClassification _remove;
  final SetPrimaryProductClassification _setPrimary;

  String? _productId;

  /// Loads the product and its tax setup.
  Future<void> load(String productId) async {
    _productId = productId;
    emit(state.copyWith(status: ViewStatus.loading));
    await _refresh(initial: true);
  }

  /// Chooses the category (`null` = inherit from the tax profile).
  Future<void> setCategory(String? categoryId) async {
    final product = state.product;
    if (product == null || state.busy) {
      return;
    }
    emit(state.copyWith(busy: true));
    final result = await _setTreatment(
      product.id,
      taxCategoryId: categoryId,
      taxOverrideId: product.taxOverrideId,
    );
    await _refresh(
      message: result.isFailure ? _messageOf(result.failureOrNull!) : 'Tax category saved.',
    );
  }

  /// Chooses the explicit override (`null` = none).
  Future<void> setOverride(String? overrideId) async {
    final product = state.product;
    if (product == null || state.busy) {
      return;
    }
    emit(state.copyWith(busy: true));
    final result = await _setTreatment(
      product.id,
      taxCategoryId: product.taxCategoryId,
      taxOverrideId: overrideId,
    );
    await _refresh(
      message: result.isFailure ? _messageOf(result.failureOrNull!) : 'Tax override saved.',
    );
  }

  /// Adds a classification. Returns the validation failure, if any, so the
  /// form can show field errors.
  Future<Failure?> addClassification({
    required String system,
    required String code,
    required ClassificationType type,
    String description = '',
    String country = '',
    bool makePrimary = false,
  }) async {
    final id = _productId;
    if (id == null) {
      return null;
    }
    final result = await _add(
      productId: id,
      system: system,
      code: code,
      type: type,
      description: description,
      country: country,
      makePrimary: makePrimary,
    );
    if (result.isFailure) {
      return result.failureOrNull;
    }
    await _refresh(message: 'Classification added.');
    return null;
  }

  /// Edits a classification. Returns the failure, if any.
  Future<Failure?> updateClassification(
    ProductClassification existing, {
    required String system,
    required String code,
    required ClassificationType type,
    String description = '',
    String country = '',
  }) async {
    final result = await _update(
      existing: existing,
      system: system,
      code: code,
      type: type,
      description: description,
      country: country,
    );
    if (result.isFailure) {
      return result.failureOrNull;
    }
    await _refresh(message: 'Classification saved.');
    return null;
  }

  /// Makes a classification the one printed on documents.
  Future<void> makePrimary(ProductClassification c) async {
    final result = await _setPrimary(c.productId, c.id);
    await _refresh(
      message: result.isFailure ? result.failureOrNull!.message : '${c.system.displayName} ${c.code} is now primary.',
    );
  }

  /// Removes a classification. Posted documents keep their own copy.
  Future<void> removeClassification(ProductClassification c) async {
    final result = await _remove(c.id);
    await _refresh(
      message: result.isFailure ? result.failureOrNull!.message : 'Classification removed.',
    );
  }

  /// Finds codes already entered on other products (works offline).
  Future<void> searchSuggestions(String query) async {
    if (query.trim().length < 2) {
      emit(state.copyWith(suggestions: const []));
      return;
    }
    final result = await _classifications.search(query, limit: 6);
    emit(state.copyWith(suggestions: result.valueOrNull ?? const []));
  }

  static String _messageOf(Failure failure) =>
      failure is ValidationFailure && failure.fieldErrors.isNotEmpty
      ? failure.fieldErrors.values.first
      : failure.message;

  Future<void> _refresh({bool initial = false, String? message}) async {
    final id = _productId;
    if (id == null) {
      return;
    }
    final loaded = await _products.getById(id);
    final product = loaded.valueOrNull;
    if (product == null) {
      emit(
        ProductTaxState(
          status: ViewStatus.failure,
          error: loaded.failureOrNull?.message ?? 'This product no longer exists.',
        ),
      );
      return;
    }
    final config = (await _tax.loadConfiguration()).valueOrNull;
    final context = (await _tax.loadContext()).valueOrNull;
    final classes = (await _classifications.listForProduct(id)).valueOrNull ?? const <ProductClassification>[];
    EffectiveTaxCategory? effective;
    TaxCategory? category;
    if (config != null && context != null) {
      effective = ProductTaxClassifier.resolve(
        configuration: config,
        taxProfileId: context.taxProfileId,
        productTaxCategoryId: product.taxCategoryId,
        productTaxOverrideId: product.taxOverrideId,
      ).valueOrNull;
      category = effective == null ? null : config.category(effective.categoryId);
    }
    emit(
      ProductTaxState(
        status: ViewStatus.loaded,
        product: product,
        // The product's current choice stays listed even if it was switched
        // off since, so the screen can show and replace it.
        categories: config?.categories
                .where((c) => c.isActive || c.id == product.taxCategoryId)
                .toList() ??
            const [],
        overrides: config?.overrides
                .where((o) => o.isActive || o.id == product.taxOverrideId)
                .toList() ??
            const [],
        effective: effective,
        effectiveCategory: category,
        hasProfile: context != null,
        classifications: classes,
        messageSerial: state.messageSerial,
      ).copyWith(message: message),
    );
  }
}
