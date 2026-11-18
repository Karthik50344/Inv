import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_bloc.dart';
import 'package:inventrix/features/products/presentation/bloc/product_event.dart';
import 'package:inventrix/features/products/presentation/bloc/product_state.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
import 'package:inventrix/shared/presentation/widgets/stored_image.dart';

/// Product list with search, category filter and archive toggle.
class ProductsPage extends StatelessWidget {
  /// Creates the page. Provide a [ProductBloc] above it.
  const ProductsPage({super.key});

  Future<void> _push(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
  }) async {
    final bloc = context.read<ProductBloc>();
    await context.pushNamed(name, pathParameters: params);
    bloc.add(const ProductsRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductBloc, ProductState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<ProductBloc>();
        return Scaffold(
          appBar: AppAppBar(
            title: 'Products',
            actions: [
              AppIconButton(
                key: const Key('open_categories'),
                tooltip: 'Categories',
                icon: Icons.category_outlined,
                onPressed: () => _push(context, RouteNames.categories),
              ),
              AppIconButton(
                key: const Key('open_units'),
                tooltip: 'Units',
                icon: Icons.straighten,
                onPressed: () => _push(context, RouteNames.units),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_product'),
            onPressed: () => _push(context, RouteNames.productNew),
            icon: const Icon(Icons.add),
            label: const Text('Product'),
          ),
          body: Column(
            children: [
              AppSearchField(
                hintText: 'Search name, SKU or barcode',
                onChanged: (query) => bloc.add(ProductsSearchChanged(query)),
              ),
              _FilterBar(state: state),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ProductState state) {
    final bloc = context.read<ProductBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load products.',
          onRetry: () => bloc.add(const ProductsRefreshed()),
        );
      case ViewStatus.empty:
        return EmptyState(
          icon: Icons.inventory_2_outlined,
          title: state.isFiltered ? 'No matching products' : 'No products yet',
          message: state.isFiltered
              ? 'Try changing the search or filters.'
              : 'Add your first product to start tracking stock and sales.',
          action: state.isFiltered
              ? null
              : AppButton(
                  key: const Key('empty_add_product'),
                  label: 'Add product',
                  icon: Icons.add,
                  onPressed: () => _push(context, RouteNames.productNew),
                ),
        );
      case ViewStatus.loaded:
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const ProductsRefreshed()),
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              96, // clears the floating action button
            ),
            itemCount: state.products.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final Product product = state.products[index];
              final unit = state.units[product.unitId];
              final tokens = context.appColors;
              final theme = Theme.of(context);
              return AppCard(
                key: Key('product_${product.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _push(
                  context,
                  RouteNames.productDetail,
                  params: {'id': product.id},
                ),
                child: Row(
                  children: [
                    StoredImage(
                      relativePath: product.imagePath,
                      resolvePath: bloc.resolveImagePath,
                      size: 52,
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.sku}'
                            '${unit == null ? '' : ' · ${unit.symbol}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.hGap8,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppCurrencyText(product.sellingPrice),
                        if (product.isArchived) ...[
                          AppSpacing.gap4,
                          const AppBadge(label: 'Archived'),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProductBloc>();
    return Column(
      children: [
        if (state.categories.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s4,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s8),
                  child: AppChip(
                    label: 'All',
                    selected: state.filter.categoryId == null,
                    onSelected: (_) =>
                        bloc.add(const ProductsCategoryFilterChanged(null)),
                  ),
                ),
                for (final category in state.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: AppChip(
                      label: category.name,
                      selected: state.filter.categoryId == category.id,
                      onSelected: (_) =>
                          bloc.add(ProductsCategoryFilterChanged(category.id)),
                    ),
                  ),
              ],
            ),
          ),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
          ),
          title: const Text('Show archived'),
          value: state.filter.includeArchived,
          onChanged: (value) =>
              bloc.add(ProductsArchivedFilterChanged(includeArchived: value)),
        ),
      ],
    );
  }
}
