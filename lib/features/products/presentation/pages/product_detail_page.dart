import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
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
          appBar: AppAppBar(
            title: product?.name ?? 'Product',
            actions: [
              if (product != null) ...[
                AppIconButton(
                  key: const Key('edit_product'),
                  tooltip: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: () async {
                    await context.pushNamed(
                      RouteNames.productEdit,
                      pathParameters: {'id': product.id},
                    );
                    await cubit.load(product.id);
                  },
                ),
                AppIconButton(
                  key: const Key('product_tax'),
                  tooltip: 'Tax and classification',
                  icon: Icons.percent,
                  onPressed: () async {
                    await context.pushNamed(
                      RouteNames.productTax,
                      pathParameters: {'id': product.id},
                    );
                    await cubit.load(product.id);
                  },
                ),
                AppIconButton(
                  key: const Key('toggle_archive_product'),
                  tooltip: product.isArchived ? 'Restore' : 'Archive',
                  icon: product.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
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
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final unitSymbol = state.unit?.symbol ?? '';
    return ListView(
      padding: AppSpacing.page,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            children: [
              StoredImage(
                relativePath: product.imagePath,
                resolvePath: cubit.resolveImagePath,
                size: 140,
              ),
              AppSpacing.gap16,
              Text(
                product.name,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (product.isArchived) ...[
                AppSpacing.gap8,
                const AppBadge(label: 'Archived'),
              ],
            ],
          ),
        ),
        AppSpacing.gap12,
        Row(
          children: [
            Expanded(
              child: _PriceCard(
                label: 'Purchase price',
                child: AppCurrencyText(
                  product.purchasePrice,
                  size: AppCurrencySize.medium,
                ),
              ),
            ),
            AppSpacing.hGap12,
            Expanded(
              child: _PriceCard(
                label: 'Selling price',
                child: AppCurrencyText(
                  product.sellingPrice,
                  size: AppCurrencySize.medium,
                  tone: AppTone.success,
                ),
              ),
            ),
          ],
        ),
        const AppSectionHeader(
          title: 'Details',
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s24,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s4,
          ),
          child: Column(
            children: [
              _InfoRow('SKU', product.sku),
              _InfoRow('Barcode', product.barcode ?? '—'),
              _InfoRow('Category', state.category?.name ?? '—'),
              _InfoRow(
                'Unit',
                state.unit == null
                    ? '—'
                    : '${state.unit!.name} ($unitSymbol)',
              ),
              _InfoRow(
                'Prices include tax',
                product.priceIncludesTax ? 'Yes' : 'No',
              ),
              _InfoRow(
                'Tax',
                state.taxRate == null
                    ? 'None'
                    : '${state.taxRate!.name} (${state.taxRate!.percentLabel}%)',
              ),
              _InfoRow(
                'Reorder level',
                '${product.reorderLevel.toDecimalString()} $unitSymbol'.trim(),
                last: true,
              ),
            ],
          ),
        ),
        if (product.description != null) ...[
          const AppSectionHeader(
            title: 'Description',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s24,
              AppSpacing.s4,
              AppSpacing.s8,
            ),
          ),
          AppCard(
            child: Text(
              product.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          AppSpacing.gap8,
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          AppSpacing.hGap16,
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
