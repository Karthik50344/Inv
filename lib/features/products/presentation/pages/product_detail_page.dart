import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/stored_image.dart';

/// Read-only product details with edit and archive actions.
class ProductDetailPage extends StatelessWidget {
  /// Creates the page for [productId]. Provide a [ProductDetailCubit] above.
  const ProductDetailPage({required this.productId, super.key});

  /// Id of the product to show.
  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductDetailCubit, ProductDetailState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.status == DetailStatus.loaded &&
          current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<ProductDetailCubit>();
        final product = state.product;
        return Scaffold(
          appBar: AppBar(
            title: Text(product?.name ?? 'Product'),
            actions: [
              if (product != null) ...[
                IconButton(
                  key: const Key('edit_product'),
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await context.pushNamed(
                      RouteNames.productEdit,
                      pathParameters: {'id': product.id},
                    );
                    await cubit.load(product.id);
                  },
                ),
                IconButton(
                  key: const Key('toggle_archive_product'),
                  tooltip: product.isArchived ? 'Restore' : 'Archive',
                  icon: Icon(
                    product.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  onPressed: () async {
                    if (product.isArchived) {
                      await cubit.restore();
                      return;
                    }
                    final confirmed = await showConfirmationDialog(
                      context,
                      title: 'Archive product?',
                      message:
                          'It will be hidden from lists and new '
                          'documents. History is kept.',
                      confirmLabel: 'Archive',
                      destructive: true,
                    );
                    if (confirmed) {
                      await cubit.archive();
                    }
                  },
                ),
              ],
            ],
          ),
          body: switch (state.status) {
            DetailStatus.loading => const LoadingIndicator(),
            DetailStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Product not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the product.',
              onRetry: () => cubit.load(productId),
            ),
            DetailStatus.loaded => _Details(state: state, cubit: cubit),
          },
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state, required this.cubit});

  final ProductDetailState state;
  final ProductDetailCubit cubit;

  @override
  Widget build(BuildContext context) {
    final Product product = state.product!;
    const formatter = MoneyFormatter();
    final unitSymbol = state.unit?.symbol ?? '';
    Widget row(String label, String value) =>
        ListTile(dense: true, title: Text(label), trailing: Text(value));
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        Center(
          child: StoredImage(
            relativePath: product.imagePath,
            resolvePath: cubit.resolveImagePath,
            size: 160,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        if (product.isArchived)
          const Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text('Archived')),
          ),
        row('SKU', product.sku),
        row('Barcode', product.barcode ?? '—'),
        row('Category', state.category?.name ?? '—'),
        row(
          'Unit',
          state.unit == null ? '—' : '${state.unit!.name} ($unitSymbol)',
        ),
        row('Purchase price', formatter.format(product.purchasePrice)),
        row('Selling price', formatter.format(product.sellingPrice)),
        row('Prices include tax', product.priceIncludesTax ? 'Yes' : 'No'),
        row(
          'Tax',
          state.taxRate == null
              ? 'None'
              : '${state.taxRate!.name} (${state.taxRate!.percentLabel}%)',
        ),
        row(
          'Reorder level',
          '${product.reorderLevel.toDecimalString()} $unitSymbol'.trim(),
        ),
        if (product.description != null) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            child: Text(product.description!),
          ),
        ],
      ],
    );
  }
}
