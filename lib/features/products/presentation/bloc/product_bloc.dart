import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/features/products/domain/repositories/image_storage.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_event.dart';
import 'package:inventrix/features/products/presentation/bloc/product_state.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Lists, searches and filters products.
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  /// Creates the bloc.
  ProductBloc({
    required ProductRepository products,
    required CategoryRepository categories,
    required UnitRepository units,
    required ArchiveProduct archiveProduct,
    required RestoreProduct restoreProduct,
    required ImageStorage imageStorage,
  }) : _products = products,
       _categories = categories,
       _units = units,
       _archive = archiveProduct,
       _restore = restoreProduct,
       _images = imageStorage,
       super(const ProductState()) {
    on<ProductsStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<ProductsRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<ProductsSearchChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(query: event.query)));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<ProductsCategoryFilterChanged>((event, emit) {
      final filter = event.categoryId == null
          ? state.filter.copyWith(clearCategory: true)
          : state.filter.copyWith(categoryId: event.categoryId);
      emit(state.copyWith(filter: filter));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<ProductsArchivedFilterChanged>((event, emit) {
      emit(
        state.copyWith(
          filter: state.filter.copyWith(includeArchived: event.includeArchived),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<ProductArchiveToggled>(
      _onArchiveToggled,
      transformer: sequentialTransformer(),
    );
  }

  final ProductRepository _products;
  final CategoryRepository _categories;
  final UnitRepository _units;
  final ArchiveProduct _archive;
  final RestoreProduct _restore;
  final ImageStorage _images;

  /// Resolves a stored relative image path for display.
  Future<String> resolveImagePath(String relativePath) =>
      _images.resolvePath(relativePath);

  Future<void> _load(Emitter<ProductState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final ProductFilter filter = state.filter;
    final categories = await _categories.search();
    final units = await _units.search(includeArchived: true);
    final products = await _products.search(filter);

    final failure =
        categories.failureOrNull ??
        units.failureOrNull ??
        products.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final list = products.valueOrNull!;
    emit(
      state.copyWith(
        status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        products: list,
        categories: categories.valueOrNull,
        units: {for (final unit in units.valueOrNull!) unit.id: unit},
      ),
    );
  }

  Future<void> _onArchiveToggled(
    ProductArchiveToggled event,
    Emitter<ProductState> emit,
  ) async {
    final result = event.archive
        ? await _archive(event.productId)
        : await _restore(event.productId);
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    await _load(emit);
  }
}
