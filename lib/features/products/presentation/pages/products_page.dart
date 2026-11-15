import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_bloc.dart';
import 'package:inventrix/features/products/presentation/bloc/product_event.dart';
import 'package:inventrix/features/products/presentation/bloc/product_state.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';
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
          appBar: AppBar(
            title: const Text('Products'),
            actions: [
              IconButton(
                key: const Key('open_categories'),
                tooltip: 'Categories',
                icon: const Icon(Icons.category_outlined),
                onPressed: () => _push(context, RouteNames.categories),
              ),
              IconButton(
                key: const Key('open_units'),
                tooltip: 'Units',
                icon: const Icon(Icons.straighten),
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
              SearchField(
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
        );
      case ViewStatus.loaded:
        const formatter = MoneyFormatter();
        return ListView.separated(
          itemCount: state.products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final Product product = state.products[index];
            final unit = state.units[product.unitId];
            return ListTile(
              key: Key('product_${product.id}'),
              leading: StoredImage(
                relativePath: product.imagePath,
                resolvePath: bloc.resolveImagePath,
                size: 48,
              ),
              title: Text(product.name),
              subtitle: Text(
                '${product.sku}'
                '${unit == null ? '' : ' · ${unit.symbol}'}'
                ' · ${formatter.format(product.sellingPrice)}',
              ),
              trailing: product.isArchived
                  ? const Chip(label: Text('Archived'))
                  : const Icon(Icons.chevron_right),
              onTap: () => _push(
                context,
                RouteNames.productDetail,
                params: {'id': product.id},
              ),
            );
          },
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
                horizontal: AppDimensions.spaceMd,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.spaceSm),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: state.filter.categoryId == null,
                    onSelected: (_) =>
                        bloc.add(const ProductsCategoryFilterChanged(null)),
                  ),
                ),
                for (final category in state.categories)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppDimensions.spaceSm,
                    ),
                    child: ChoiceChip(
                      label: Text(category.name),
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
          title: const Text('Show archived'),
          value: state.filter.includeArchived,
          onChanged: (value) =>
              bloc.add(ProductsArchivedFilterChanged(includeArchived: value)),
        ),
      ],
    );
  }
}
