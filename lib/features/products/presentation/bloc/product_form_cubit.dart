import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/update_product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/features/settings/domain/usecases/create_tax_rate.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Drives the create/edit product form.
class ProductFormCubit extends Cubit<ProductFormState> {
  /// Creates the cubit.
  ProductFormCubit({
    required ProductRepository products,
    required CategoryRepository categories,
    required UnitRepository units,
    required TaxRateRepository taxRates,
    required SettingsRepository settings,
    required CreateProduct createProduct,
    required UpdateProduct updateProduct,
    required CreateTaxRate createTaxRate,
    required ImageStorage imageStorage,
  }) : _products = products,
       _categories = categories,
       _units = units,
       _taxRates = taxRates,
       _settings = settings,
       _create = createProduct,
       _update = updateProduct,
       _createTaxRate = createTaxRate,
       _images = imageStorage,
       super(const ProductFormState());

  final ProductRepository _products;
  final CategoryRepository _categories;
  final UnitRepository _units;
  final TaxRateRepository _taxRates;
  final SettingsRepository _settings;
  final CreateProduct _create;
  final UpdateProduct _update;
  final CreateTaxRate _createTaxRate;
  final ImageStorage _images;

  /// Loads reference data and, when [productId] is given, the product.
  Future<void> load({String? productId}) async {
    emit(const ProductFormState());
    Product? product;
    if (productId != null) {
      final loaded = await _products.getById(productId);
      product = loaded.valueOrNull;
      if (product == null) {
        final failure = loaded.failureOrNull!;
        emit(
          state.copyWith(
            loadStatus: failure is NotFoundFailure
                ? FormLoadStatus.notFound
                : FormLoadStatus.failure,
            message: failure.userMessage,
          ),
        );
        return;
      }
    }
    final categories = await _categories.search(includeArchived: true);
    final units = await _units.search(includeArchived: true);
    final taxRates = await _taxRates.list(includeArchived: true);
    final currency = await _settings.getCurrencyConfig();
    final failure =
        categories.failureOrNull ??
        units.failureOrNull ??
        taxRates.failureOrNull ??
        currency.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          loadStatus: FormLoadStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    // Archived items stay selectable only when the product already uses them.
    emit(
      state.copyWith(
        loadStatus: FormLoadStatus.ready,
        product: product,
        categories: categories.valueOrNull!
            .where((c) => !c.isArchived || c.id == product?.categoryId)
            .toList(),
        units: units.valueOrNull!
            .where((u) => !u.isArchived || u.id == product?.unitId)
            .toList(),
        taxRates: taxRates.valueOrNull!
            .where((t) => !t.isArchived || t.id == product?.taxRateId)
            .toList(),
        currency: currency.valueOrNull,
        imagePath: product?.imagePath,
      ),
    );
  }

  /// Resolves a stored relative image path for display.
  Future<String> resolveImagePath(String relativePath) =>
      _images.resolvePath(relativePath);

  /// Copies a picked image into app storage and selects it.
  Future<void> attachImage(String sourcePath) async {
    final result = await _images.storeProductImage(sourcePath);
    if (isClosed) {
      return;
    }
    result.when(
      success: (path) => emit(state.copyWith(imagePath: path)),
      failure: (failure) => emit(state.copyWith(message: failure.userMessage)),
    );
  }

  /// Removes the selected image.
  void removeImage() => emit(state.copyWith(clearImage: true));

  /// Creates a tax rate from the form and makes it available for selection.
  Future<Result<TaxRate>> createTaxRate({
    required String name,
    required String ratePercent,
    bool isExempt = false,
  }) async {
    final result = await _createTaxRate(
      name: name,
      ratePercent: ratePercent,
      isExempt: isExempt,
    );
    final created = result.valueOrNull;
    if (created != null && !isClosed) {
      emit(state.copyWith(taxRates: [...state.taxRates, created]));
    }
    return result;
  }

  /// Validates and saves the product.
  Future<void> submit(ProductDraft draft) async {
    if (state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final existing = state.product;
    final result = existing == null
        ? await _create(draft)
        : await _update(existing.id, draft);
    if (isClosed) {
      return;
    }
    result.when(
      success: (product) => emit(
        state.copyWith(
          submitStatus: SubmitStatus.success,
          product: product,
          savedProductId: product.id,
        ),
      ),
      failure: (failure) => emit(
        failure is ValidationFailure
            ? state.copyWith(
                submitStatus: SubmitStatus.validationError,
                fieldErrors: failure.fieldErrors,
                message: failure.fieldErrors.isEmpty ? failure.message : null,
              )
            : state.copyWith(
                submitStatus: SubmitStatus.failure,
                message: failure.userMessage,
              ),
      ),
    );
  }
}
