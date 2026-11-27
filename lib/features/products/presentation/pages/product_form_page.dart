import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/presentation/widgets/tax_rate_form_dialog.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
import 'package:inventrix/shared/presentation/widgets/stored_image.dart';

/// Create/edit product form. Pops with `true` after a successful save.
class ProductFormPage extends StatefulWidget {
  /// Creates the form; pass [productId] to edit. Provide a
  /// [ProductFormCubit] above it.
  const ProductFormPage({this.productId, super.key});

  /// Product being edited, or `null` to create.
  final String? productId;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _description = TextEditingController();
  final _purchase = TextEditingController();
  final _selling = TextEditingController();
  final _reorder = TextEditingController();
  String? _categoryId;
  String? _unitId;
  String? _taxRateId;
  bool _includesTax = false;
  bool _populated = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _sku,
      _barcode,
      _description,
      _purchase,
      _selling,
      _reorder,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(ProductFormState state) {
    if (_populated) {
      return;
    }
    _populated = true;
    final product = state.product;
    if (product == null) {
      // A new product starts with the defaults chosen in the settings.
      final rateId = state.defaultTaxRateId;
      if (rateId != null && state.taxRates.any((t) => t.id == rateId)) {
        _taxRateId = rateId;
      }
      _includesTax = state.defaultPriceIncludesTax;
      return;
    }
    _name.text = product.name;
    _sku.text = product.sku;
    _barcode.text = product.barcode ?? '';
    _description.text = product.description ?? '';
    _purchase.text = product.purchasePrice.toPlainString();
    _selling.text = product.sellingPrice.toPlainString();
    _reorder.text = product.reorderLevel.toDecimalString();
    _categoryId = product.categoryId;
    _unitId = product.unitId;
    _taxRateId = product.taxRateId;
    _includesTax = product.priceIncludesTax;
  }

  Future<void> _pickImage(ProductFormCubit cubit) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result.single.path;
    if (path != null) {
      await cubit.attachImage(path);
    }
  }

  Future<void> _addTaxRate(ProductFormCubit cubit) async {
    final created = await showDialog<TaxRate>(
      context: context,
      builder: (_) => TaxRateFormDialog(
        onSubmit: (name, percent, exempt) => cubit.createTaxRate(
          name: name,
          ratePercent: percent,
          isExempt: exempt,
        ),
      ),
    );
    if (created != null) {
      setState(() => _taxRateId = created.id);
    }
  }

  void _submit(ProductFormCubit cubit, ProductFormState state) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    cubit.submit(
      ProductDraft(
        name: _name.text,
        sku: _sku.text,
        barcode: _barcode.text,
        description: _description.text,
        categoryId: _categoryId,
        unitId: _unitId ?? '',
        purchasePrice: _purchase.text,
        sellingPrice: _selling.text,
        priceIncludesTax: _includesTax,
        taxRateId: _taxRateId,
        reorderLevel: _reorder.text,
        imagePath: state.imagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductFormCubit, ProductFormState>(
      listenWhen: (previous, current) =>
          previous.loadStatus != current.loadStatus ||
          previous.submitStatus != current.submitStatus ||
          (current.message != null && current.message != previous.message),
      listener: (context, state) {
        if (state.loadStatus == FormLoadStatus.ready) {
          setState(() => _populate(state));
        }
        if (state.submitStatus == SubmitStatus.success) {
          context.pop(true);
          return;
        }
        if (state.message != null && state.loadStatus == FormLoadStatus.ready) {
          showAppMessage(context, state.message!);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ProductFormCubit>();
        final editing = widget.productId != null;
        return Scaffold(
          appBar: AppAppBar(title: editing ? 'Edit product' : 'New product'),
          body: switch (state.loadStatus) {
            FormLoadStatus.loading => const LoadingIndicator(),
            FormLoadStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Product not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            FormLoadStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the form.',
              onRetry: () => cubit.load(productId: widget.productId),
            ),
            FormLoadStatus.ready => _form(context, cubit, state),
          },
        );
      },
    );
  }

  Widget _form(
    BuildContext context,
    ProductFormCubit cubit,
    ProductFormState state,
  ) {
    final errors = state.fieldErrors;
    final currency = state.currency?.currencyCode ?? '';
    final saving = state.submitStatus == SubmitStatus.submitting;
    final unit = state.units.where((u) => u.id == _unitId).firstOrNull;
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: child,
    );
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          gap(
            Row(
              children: [
                StoredImage(
                  relativePath: state.imagePath,
                  resolvePath: cubit.resolveImagePath,
                  size: 96,
                  placeholder: const Icon(Icons.add_a_photo_outlined),
                ),
                const SizedBox(width: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s8,
                  children: [
                    AppButton(
                      key: const Key('pick_image'),
                      label: state.imagePath == null
                          ? 'Add image'
                          : 'Change image',
                      icon: Icons.photo_camera_outlined,
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.small,
                      onPressed: () => _pickImage(cubit),
                    ),
                    if (state.imagePath != null)
                      AppButton(
                        label: 'Remove',
                        variant: AppButtonVariant.text,
                        size: AppButtonSize.small,
                        onPressed: cubit.removeImage,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const AppSectionHeader(
            title: 'Basic information',
            padding: EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s12),
          ),
          gap(
            TextFormField(
              key: const Key('product_name'),
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name *',
                errorText: errors['name'],
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Name is required.'
                  : null,
            ),
          ),
          gap(
            TextFormField(
              key: const Key('product_sku'),
              controller: _sku,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'SKU',
                helperText: widget.productId == null
                    ? 'Leave blank to generate automatically.'
                    : null,
                errorText: errors['sku'],
              ),
              validator: (value) =>
                  widget.productId != null && (value ?? '').trim().isEmpty
                  ? 'SKU is required.'
                  : null,
            ),
          ),
          gap(
            TextFormField(
              key: const Key('product_barcode'),
              controller: _barcode,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Barcode',
                errorText: errors['barcode'],
              ),
            ),
          ),
          gap(
            DropdownButtonFormField<String?>(
              key: const Key('product_category'),
              initialValue: _categoryId,
              decoration: InputDecoration(
                labelText: 'Category',
                errorText: errors['categoryId'],
              ),
              items: [
                const DropdownMenuItem<String?>(child: Text('None')),
                for (final category in state.categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
          ),
          gap(
            DropdownButtonFormField<String>(
              key: const Key('product_unit'),
              initialValue: _unitId,
              decoration: InputDecoration(
                labelText: 'Unit *',
                errorText: errors['unitId'],
                helperText: state.units.isEmpty
                    ? 'Add units first (Products > Units).'
                    : null,
              ),
              items: [
                for (final u in state.units)
                  DropdownMenuItem(
                    value: u.id,
                    child: Text('${u.name} (${u.symbol})'),
                  ),
              ],
              validator: (value) => value == null ? 'Select a unit.' : null,
              onChanged: (value) => setState(() => _unitId = value),
            ),
          ),
          const AppSectionHeader(
            title: 'Pricing and tax',
            padding: EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s12),
          ),
          gap(
            TextFormField(
              key: const Key('product_purchase'),
              controller: _purchase,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Purchase price',
                prefixText: '$currency ',
                errorText: errors['purchasePrice'],
              ),
            ),
          ),
          gap(
            TextFormField(
              key: const Key('product_selling'),
              controller: _selling,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Selling price',
                prefixText: '$currency ',
                errorText: errors['sellingPrice'],
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prices include tax'),
            value: _includesTax,
            onChanged: (value) => setState(() => _includesTax = value),
          ),
          gap(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: const Key('product_tax'),
                    initialValue: _taxRateId,
                    decoration: InputDecoration(
                      labelText: 'Tax rate',
                      errorText: errors['taxRateId'],
                    ),
                    items: [
                      const DropdownMenuItem<String?>(child: Text('None')),
                      for (final rate in state.taxRates)
                        DropdownMenuItem<String?>(
                          value: rate.id,
                          child: Text(
                            rate.isExempt
                                ? '${rate.name} (exempt)'
                                : '${rate.name} (${rate.percentLabel}%)',
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _taxRateId = value),
                  ),
                ),
                AppIconButton(
                  key: const Key('add_tax_rate'),
                  tooltip: 'New tax rate',
                  icon: Icons.add_circle_outline,
                  onPressed: () => _addTaxRate(cubit),
                ),
              ],
            ),
          ),
          const AppSectionHeader(
            title: 'Stock and notes',
            padding: EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s12),
          ),
          gap(
            TextFormField(
              key: const Key('product_reorder'),
              controller: _reorder,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Reorder level',
                helperText: unit == null
                    ? 'Select a unit to see allowed precision.'
                    : unit.decimalPlaces == 0
                    ? 'Whole numbers only.'
                    : 'Up to ${unit.decimalPlaces} decimal places.',
                suffixText: unit?.symbol,
                errorText: errors['reorderLevel'],
              ),
            ),
          ),
          gap(
            TextFormField(
              key: const Key('product_description'),
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                errorText: errors['description'],
              ),
            ),
          ),
          AppButton(
            key: const Key('save_product'),
            label: 'Save',
            icon: Icons.check,
            expand: true,
            loading: saving,
            onPressed: () => _submit(cubit, state),
          ),
        ],
      ),
    );
  }
}
