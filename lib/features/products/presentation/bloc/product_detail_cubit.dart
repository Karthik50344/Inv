import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';

/// Load status of the detail screen.
enum DetailStatus { loading, loaded, notFound, failure }

/// State of the product detail screen.
final class ProductDetailState extends Equatable {
  /// Creates a state.
  const ProductDetailState({
    this.status = DetailStatus.loading,
    this.product,
    this.category,
    this.unit,
    this.taxRate,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The product.
  final Product? product;

  /// Its category, if any.
  final Category? category;

  /// Its unit.
  final UnitOfMeasure? unit;

  /// Its tax rate, if any.
  final TaxRate? taxRate;

  /// One-shot user-facing message.
  final String? message;

  @override
  List<Object?> get props => [
    status,
    product,
    category,
    unit,
    taxRate,
    message,
  ];
}

/// Loads one product (by id) with its related master data.
class ProductDetailCubit extends Cubit<ProductDetailState> {
  /// Creates the cubit.
  ProductDetailCubit({
    required ProductRepository products,
    required CategoryRepository categories,
    required UnitRepository units,
    required TaxRateRepository taxRates,
    required ArchiveProduct archiveProduct,
    required RestoreProduct restoreProduct,
    required ImageStorage imageStorage,
  }) : _products = products,
       _categories = categories,
       _units = units,
       _taxRates = taxRates,
       _archive = archiveProduct,
       _restore = restoreProduct,
       _images = imageStorage,
       super(const ProductDetailState());

  final ProductRepository _products;
  final CategoryRepository _categories;
  final UnitRepository _units;
  final TaxRateRepository _taxRates;
  final ArchiveProduct _archive;
  final RestoreProduct _restore;
  final ImageStorage _images;
  String? _id;

  /// Resolves a stored relative image path for display.
  Future<String> resolveImagePath(String relativePath) =>
      _images.resolvePath(relativePath);

  /// Loads product [id]; unknown ids end in [DetailStatus.notFound].
  Future<void> load(String id) async {
    _id = id;
    emit(const ProductDetailState());
    final result = await _products.getById(id);
    final product = result.valueOrNull;
    if (product == null) {
      final failure = result.failureOrNull!;
      emit(
        ProductDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final category = product.categoryId == null
        ? null
        : (await _categories.getById(product.categoryId!)).valueOrNull;
    final unit = (await _units.getById(product.unitId)).valueOrNull;
    final taxRate = product.taxRateId == null
        ? null
        : (await _taxRates.getById(product.taxRateId!)).valueOrNull;
    if (isClosed) {
      return;
    }
    emit(
      ProductDetailState(
        status: DetailStatus.loaded,
        product: product,
        category: category,
        unit: unit,
        taxRate: taxRate,
      ),
    );
  }

  /// Archives the product and reloads.
  Future<void> archive() => _toggle(archive: true);

  /// Restores the product and reloads.
  Future<void> restore() => _toggle(archive: false);

  Future<void> _toggle({required bool archive}) async {
    final id = _id;
    if (id == null) {
      return;
    }
    final result = archive ? await _archive(id) : await _restore(id);
    final failure = result.failureOrNull;
    if (failure != null && !isClosed) {
      emit(
        ProductDetailState(
          status: state.status,
          product: state.product,
          category: state.category,
          unit: state.unit,
          taxRate: state.taxRate,
          message: failure.userMessage,
        ),
      );
      return;
    }
    await load(id);
  }
}
