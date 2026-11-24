import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/products/presentation/bloc/product_tax_cubit.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// How one product is taxed (inherited, assigned or overridden, and the
/// treatment) and its classification codes (HSN / SAC / HS / custom).
class ProductTaxPage extends StatelessWidget {
  /// Creates the page. Provide a [ProductTaxCubit] above.
  const ProductTaxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductTaxCubit, ProductTaxState>(
      listenWhen: (a, b) => a.messageSerial != b.messageSerial && b.message != null,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        return Scaffold(
          appBar: AppAppBar(title: state.product?.name ?? 'Tax and classification'),
          body: switch (state.status) {
            ViewStatus.initial || ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure || ViewStatus.empty => ErrorState(
              message: state.error ?? 'Could not load the product.',
            ),
            ViewStatus.loaded => _Content(state: state),
          },
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final ProductTaxState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductTaxCubit>();
    final theme = Theme.of(context);
    final product = state.product!;
    return AppContentWidth(
      child: ListView(
        padding: AppSpacing.page,
        children: [
          _Effective(state: state),
          const AppSectionHeader(title: 'Tax category'),
          AppDropdown<String?>(
            label: 'Category',
            value: product.taxCategoryId,
            items: [
              const AppDropdownItem<String?>(value: null, label: 'Use the tax profile default'),
              for (final c in state.categories)
                AppDropdownItem<String?>(
                  value: c.id,
                  label: '${c.name} (${c.defaultTaxTreatment.label})${c.isActive ? '' : ' - switched off'}',
                ),
            ],
            onChanged: state.busy ? null : cubit.setCategory,
          ),
          AppSpacing.gap12,
          AppDropdown<String?>(
            label: 'Explicit override',
            value: product.taxOverrideId,
            items: [
              const AppDropdownItem<String?>(value: null, label: 'None'),
              for (final o in state.overrides)
                AppDropdownItem<String?>(value: o.id, label: '${o.name}${o.isActive ? '' : ' - switched off'}'),
            ],
            onChanged: state.busy ? null : cubit.setOverride,
          ),
          AppSpacing.gap8,
          Text(
            'An override replaces the category for this product and always '
            'comes with a recorded reason. Create overrides in Tax settings.',
            style: theme.textTheme.bodySmall,
          ),
          AppButton(
            label: 'Open tax settings',
            icon: Icons.settings_outlined,
            variant: AppButtonVariant.text,
            onPressed: () => context.push(RoutePaths.taxSettings),
          ),
          AppSectionHeader(
            title: 'Classification codes',
            subtitle: 'HSN, SAC and other codes printed on invoices',
            actionLabel: 'Add',
            onAction: () => _openForm(context, null),
          ),
          if (state.classifications.isEmpty)
            Text(
              'No code yet. Codes are optional: add one only if your invoices '
              'or your tax rules need it. Inventrix never fills in a code for you.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final c in state.classifications)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: _ClassificationTile(
                  classification: c,
                  onEdit: () => _openForm(context, c),
                ),
              ),
          AppSpacing.gap24,
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, ProductClassification? existing) {
    final cubit = context.read<ProductTaxCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ClassificationSheet(existing: existing, hasOthers: state.classifications.isNotEmpty),
      ),
    );
  }
}

class _Effective extends StatelessWidget {
  const _Effective({required this.state});

  final ProductTaxState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = state.product!;
    final category = state.effectiveCategory;
    final effective = state.effective;
    if (!state.hasProfile) {
      return AppCard(
        tone: AppTone.warning,
        child: Text(
          product.taxRateId == null
              ? 'No tax profile is set up yet, so this product is not taxed '
                    'by the configurable tax system.'
              : 'No tax profile is set up yet. This product uses its single '
                    'tax rate until you set up tax categories in Tax settings.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    if (category == null || effective == null) {
      return AppCard(
        tone: AppTone.warning,
        child: Text(
          'This product has no tax category and the tax profile has no '
          'default one. Choose a category below.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final treatment = category.defaultTaxTreatment;
    final tone = switch (treatment) {
      TaxTreatment.exempt || TaxTreatment.outOfScope => AppTone.neutral,
      TaxTreatment.zeroRated => AppTone.info,
      TaxTreatment.reverseCharge => AppTone.warning,
      _ => AppTone.success,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How this product is taxed', style: theme.textTheme.labelLarge),
          AppSpacing.gap8,
          Text(category.name, style: theme.textTheme.titleLarge),
          AppSpacing.gap8,
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              AppBadge(label: effective.source.label, tone: AppTone.brand),
              AppBadge(label: treatment.label, tone: tone),
            ],
          ),
          if (treatment == TaxTreatment.exempt || treatment == TaxTreatment.zeroRated) ...[
            AppSpacing.gap8,
            Text(
              treatment == TaxTreatment.exempt
                  ? 'No tax is charged. Sales are reported as exempt.'
                  : 'The tax rate is zero. Sales are still reported as taxable.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassificationTile extends StatelessWidget {
  const _ClassificationTile({required this.classification, required this.onEdit});

  final ProductClassification classification;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductTaxCubit>();
    final theme = Theme.of(context);
    final c = classification;
    return AppCard(
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${c.system.displayName} ${c.code}', style: theme.textTheme.titleSmall),
                    const SizedBox(width: AppSpacing.s8),
                    if (c.isPrimary) const AppBadge(label: 'Primary', tone: AppTone.success),
                  ],
                ),
                if (c.description != null) ...[
                  AppSpacing.gap4,
                  Text(c.description!, style: theme.textTheme.bodyMedium),
                ],
                AppSpacing.gap4,
                Text(
                  '${c.type.label}${c.countryCode == null ? '' : '  ·  ${c.countryCode}'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'primary':
                  await cubit.makePrimary(c);
                case 'remove':
                  final ok = await showConfirmationDialog(
                    context,
                    title: 'Remove this code?',
                    message: 'Invoices already posted keep the code they were '
                        'printed with. Only this product changes.',
                    confirmLabel: 'Remove',
                    destructive: true,
                  );
                  if (ok) {
                    await cubit.removeClassification(c);
                  }
              }
            },
            itemBuilder: (_) => [
              if (!c.isPrimary) const PopupMenuItem(value: 'primary', child: Text('Make primary')),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassificationSheet extends StatefulWidget {
  const _ClassificationSheet({required this.existing, required this.hasOthers});

  final ProductClassification? existing;
  final bool hasOthers;

  @override
  State<_ClassificationSheet> createState() => _ClassificationSheetState();
}

class _ClassificationSheetState extends State<_ClassificationSheet> {
  late String _system = widget.existing?.system.code ?? 'hsn';
  late ClassificationType _type = widget.existing?.type ?? ClassificationType.goods;
  late bool _primary = widget.existing?.isPrimary ?? !widget.hasOthers;
  late final TextEditingController _custom = TextEditingController(
    text: widget.existing != null && !widget.existing!.system.isBuiltIn ? widget.existing!.system.code : '',
  );
  late final TextEditingController _code = TextEditingController(text: widget.existing?.code ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _country = TextEditingController(text: widget.existing?.countryCode ?? '');
  Map<String, String> _errors = const {};
  bool _saving = false;

  bool get _isCustom => !const {'hsn', 'sac', 'hs'}.contains(_system);

  @override
  void initState() {
    super.initState();
    if (widget.existing != null && !widget.existing!.system.isBuiltIn) {
      _system = 'custom';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    _code.dispose();
    _description.dispose();
    _country.dispose();
    super.dispose();
  }

  void _chooseSystem(String system) => setState(() {
    _system = system;
    if (system == 'sac') {
      _type = ClassificationType.services;
    } else if (system == 'hsn' || system == 'hs') {
      _type = ClassificationType.goods;
    }
  });

  Future<void> _save() async {
    final cubit = context.read<ProductTaxCubit>();
    setState(() => _saving = true);
    final system = _isCustom ? _custom.text : _system;
    final Failure? failure = widget.existing == null
        ? await cubit.addClassification(
            system: system,
            code: _code.text,
            type: _type,
            description: _description.text,
            country: _country.text,
            makePrimary: _primary,
          )
        : await cubit.updateClassification(
            widget.existing!,
            system: system,
            code: _code.text,
            type: _type,
            description: _description.text,
            country: _country.text,
          );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _errors = failure is ValidationFailure ? failure.fieldErrors : {'code': failure.message};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = context.select((ProductTaxCubit c) => c.state.suggestions);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add classification' : 'Edit classification', style: theme.textTheme.titleMedium),
            AppSpacing.gap12,
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'hsn', label: Text('HSN')),
                ButtonSegment(value: 'sac', label: Text('SAC')),
                ButtonSegment(value: 'hs', label: Text('HS')),
                ButtonSegment(value: 'custom', label: Text('Other')),
              ],
              selected: {_isCustom ? 'custom' : _system},
              onSelectionChanged: (s) => _chooseSystem(s.first),
            ),
            if (_isCustom) ...[
              AppSpacing.gap12,
              AppTextField(label: 'System name', hint: 'For example TARIC', controller: _custom, errorText: _errors['system']),
            ],
            AppSpacing.gap12,
            AppTextField(
              label: 'Code',
              hint: _system == 'sac' ? '6 digits' : _system == 'hsn' ? '2, 4, 6 or 8 digits' : null,
              controller: _code,
              errorText: _errors['code'],
              onChanged: context.read<ProductTaxCubit>().searchSuggestions,
            ),
            if (suggestions.isNotEmpty) ...[
              AppSpacing.gap8,
              Text('Already used on your products', style: theme.textTheme.labelSmall),
              Wrap(
                spacing: AppSpacing.s8,
                children: [
                  for (final s in suggestions)
                    ActionChip(
                      label: Text('${s.system.displayName} ${s.code}'),
                      onPressed: () => setState(() {
                        _system = s.system.isBuiltIn ? s.system.code : 'custom';
                        if (!s.system.isBuiltIn) {
                          _custom.text = s.system.code;
                        }
                        _type = s.type;
                        _code.text = s.code;
                        if (_description.text.isEmpty && s.description != null) {
                          _description.text = s.description!;
                        }
                      }),
                    ),
                ],
              ),
            ],
            AppSpacing.gap12,
            AppTextField(label: 'Description (optional)', controller: _description, errorText: _errors['description']),
            AppSpacing.gap12,
            AppDropdown<ClassificationType>(
              label: 'Goods or services',
              value: _type,
              items: [for (final t in ClassificationType.values) AppDropdownItem(value: t, label: t.label)],
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            if (_errors['type'] != null)
              Text(_errors['type']!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            AppSpacing.gap12,
            AppTextField(label: 'Country (optional)', hint: 'IN', controller: _country, errorText: _errors['country']),
            if (widget.existing == null && widget.hasOthers)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Print this code on invoices'),
                value: _primary,
                onChanged: (v) => setState(() => _primary = v),
              ),
            AppSpacing.gap12,
            Text(
              'Enter the code exactly as your tax advisor gave it. Inventrix '
              'checks the shape only and never looks codes up or makes them up.',
              style: theme.textTheme.bodySmall,
            ),
            AppSpacing.gap12,
            AppButton(label: 'Save', loading: _saving, expand: true, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
