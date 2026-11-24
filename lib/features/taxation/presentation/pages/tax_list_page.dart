import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/presentation/bloc/tax_settings_cubit.dart';
import 'package:inventrix/features/taxation/presentation/support/tax_labels.dart';
import 'package:inventrix/features/taxation/presentation/widgets/tax_forms.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// The lists that can be edited on the tax settings screens.
enum TaxListKind {
  /// Tax systems.
  systems('Tax systems', 'No tax system yet', 'Add the tax system you charge under, for example GST.', TaxConfigKind.regime),

  /// Places.
  places('Places', 'No places yet', 'Places are only needed when tax differs by state, province or city.', TaxConfigKind.jurisdiction),

  /// Profiles.
  profiles('Tax profiles', 'No tax profile yet', 'A profile is the set of rules used for your documents.', TaxConfigKind.profile),

  /// Categories.
  categories('Tax categories', 'No tax categories yet', 'Add categories such as "Standard rate" or "Exempt" and give them to products.', TaxConfigKind.category),

  /// Overrides.
  overrides('Product overrides', 'No overrides yet', 'An override lets one product follow a different category, with a recorded reason.', TaxConfigKind.override),

  /// Rules.
  rules('Tax rules', 'No tax rules yet', 'Rules say which tax lines apply, where and from when.', TaxConfigKind.rule);

  const TaxListKind(this.title, this.emptyTitle, this.emptyMessage, this.configKind);

  /// Screen title.
  final String title;

  /// Title of the empty state.
  final String emptyTitle;

  /// Help text of the empty state.
  final String emptyMessage;

  /// The record kind.
  final TaxConfigKind configKind;
}

/// A list of one kind of tax record with add, edit and switch off.
class TaxListPage extends StatelessWidget {
  /// Creates the page.
  const TaxListPage({required this.kind, super.key});

  /// Which list.
  final TaxListKind kind;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaxSettingsCubit, TaxSettingsState>(
      listenWhen: (a, b) => a.messageSerial != b.messageSerial && b.message != null,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final config = state.configuration;
        return Scaffold(
          appBar: AppAppBar(
            title: kind.title,
            actions: [
              if (config != null)
                AppIconButton(
                  icon: Icons.add,
                  tooltip: 'Add',
                  onPressed: () => _openForm(context, state, null),
                ),
            ],
          ),
          body: switch (state.status) {
            ViewStatus.initial || ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure || ViewStatus.empty => ErrorState(
              message: state.error ?? 'Could not load the tax settings.',
              onRetry: () => context.read<TaxSettingsCubit>().load(),
            ),
            ViewStatus.loaded => _body(context, state, config!),
          },
        );
      },
    );
  }

  Widget _body(BuildContext context, TaxSettingsState state, TaxConfiguration c) {
    final items = _items(context, state, c);
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.add_circle_outline,
        title: kind.emptyTitle,
        message: kind.emptyMessage,
        action: AppButton(label: 'Add', icon: Icons.add, onPressed: () => _openForm(context, state, null)),
      );
    }
    return AppContentWidth(
      child: ListView.separated(
        padding: AppSpacing.page,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  List<Widget> _items(BuildContext context, TaxSettingsState state, TaxConfiguration c) {
    Widget tile({
      required String id,
      required String title,
      required String subtitle,
      required bool active,
      List<Widget> badges = const [],
      VoidCallback? onTap,
      required VoidCallback onEdit,
    }) => _Tile(
      title: title,
      subtitle: subtitle,
      active: active,
      badges: badges,
      onTap: onTap ?? onEdit,
      onEdit: onEdit,
      onToggle: () async {
        final failure = await context.read<TaxSettingsCubit>().setActive(kind.configKind, id, active: !active);
        if (failure != null && context.mounted) {
          showAppMessage(context, failure.message);
        }
      },
    );

    switch (kind) {
      case TaxListKind.systems:
        return [
          for (final r in c.regimes)
            tile(id: r.id, title: r.name, subtitle: '${r.countryCode} · ${r.currencyCode}', active: r.isActive, onEdit: () => _openForm(context, state, r)),
        ];
      case TaxListKind.places:
        return [
          for (final j in c.jurisdictions)
            tile(
              id: j.id,
              title: j.regionName ?? j.regionCode ?? j.countryCode,
              subtitle: '${TaxLabels.jurisdictionTypes[j.jurisdictionType.code] ?? j.jurisdictionType.code} · ${j.countryCode}'
                  '${j.parentJurisdictionId == null ? '' : ' · inside ${TaxLabels.place(c, j.parentJurisdictionId)}'}',
              active: j.isActive,
              onEdit: () => _openForm(context, state, j),
            ),
        ];
      case TaxListKind.profiles:
        return [
          for (final p in c.profiles)
            tile(
              id: p.id,
              title: p.name,
              subtitle: c.regime(p.regimeId)?.name ?? 'Unknown tax system',
              active: p.isActive,
              badges: [if (p.isDefault) const AppBadge(label: 'In use', tone: AppTone.success)],
              onEdit: () => _openForm(context, state, p),
            ),
        ];
      case TaxListKind.categories:
        return [
          for (final x in c.categories)
            tile(
              id: x.id,
              title: x.name,
              subtitle: '${x.code} · ${x.defaultTaxTreatment.label}',
              active: x.isActive,
              badges: [
                if (x.isActive && x.defaultTaxTreatment.computesTax && !c.rules.any((r) => r.isActive && r.taxCategoryId == x.id))
                  const AppBadge(label: 'No rule', tone: AppTone.warning),
              ],
              onEdit: () => _openForm(context, state, x),
            ),
        ];
      case TaxListKind.overrides:
        return [
          for (final o in c.overrides)
            tile(
              id: o.id,
              title: o.name,
              subtitle: 'Uses ${c.category(o.taxCategoryId)?.name ?? 'unknown category'} · ${o.reason}',
              active: o.isActive,
              onEdit: () => _openForm(context, state, o),
            ),
        ];
      case TaxListKind.rules:
        return [
          for (final r in c.rules)
            tile(
              id: r.id,
              title: '${c.category(r.taxCategoryId)?.name ?? 'Unknown category'} · ${TaxLabels.place(c, r.jurisdictionId)}',
              subtitle: TaxLabels.ruleLines(c, r, decimals: state.currencyDecimals),
              active: r.isActive,
              badges: [
                if (c.componentsOf(r.id).isEmpty) const AppBadge(label: 'No tax lines', tone: AppTone.warning),
              ],
              onTap: () async {
                await context.push(RoutePaths.taxRule(r.id));
                if (context.mounted) {
                  await context.read<TaxSettingsCubit>().load();
                }
              },
              onEdit: () => _openForm(context, state, r),
            ),
        ];
    }
  }

  Future<void> _openForm(BuildContext context, TaxSettingsState state, Object? existing) {
    final cubit = context.read<TaxSettingsCubit>();
    final c = state.configuration!;
    final id = cubit.newId();
    final Widget form;
    switch (kind) {
      case TaxListKind.systems:
        form = TaxRegimeForm(id: id, existing: existing as TaxRegime?, defaultCurrency: state.currencyCode, onSave: cubit.saveRegime);
      case TaxListKind.places:
        form = TaxJurisdictionForm(id: id, configuration: c, existing: existing as TaxJurisdiction?, onSave: cubit.saveJurisdiction);
      case TaxListKind.profiles:
        form = TaxProfileForm(id: id, configuration: c, existing: existing as TaxProfile?, onSave: cubit.saveProfile);
      case TaxListKind.categories:
        form = TaxCategoryForm(id: id, existing: existing as TaxCategory?, onSave: cubit.saveCategory);
      case TaxListKind.overrides:
        form = TaxOverrideForm(id: id, configuration: c, existing: existing as TaxOverride?, onSave: cubit.saveOverride);
      case TaxListKind.rules:
        form = TaxRuleForm(id: id, configuration: c, existing: existing as TaxRule?, onSave: cubit.saveRule);
    }
    return showTaxFormSheet(context, form);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.badges,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final bool active;
  final List<Widget> badges;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: active ? 1 : 0.6,
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: theme.textTheme.titleSmall)),
                      for (final b in badges) ...[const SizedBox(width: AppSpacing.s8), b],
                      if (!active) ...[const SizedBox(width: AppSpacing.s8), const AppBadge(label: 'Switched off')],
                    ],
                  ),
                  AppSpacing.gap4,
                  Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => v == 'edit' ? onEdit() : onToggle(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'toggle', child: Text(active ? 'Switch off' : 'Switch on')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Calculation preferences: where the business is and whether it charges
/// tax.
class TaxPreferencesPage extends StatefulWidget {
  /// Creates the page.
  const TaxPreferencesPage({super.key});

  @override
  State<TaxPreferencesPage> createState() => _TaxPreferencesPageState();
}

class _TaxPreferencesPageState extends State<TaxPreferencesPage> {
  final _country = TextEditingController();
  final _region = TextEditingController();
  bool _registered = true;
  bool _filled = false;
  Map<String, String> _errors = const {};
  bool _saving = false;

  @override
  void dispose() {
    _country.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<TaxSettingsCubit>();
    setState(() => _saving = true);
    final failure = await cubit.savePreferences(
      TaxPreferences(
        countryCode: _country.text.trim().isEmpty ? null : _country.text.trim().toUpperCase(),
        regionCode: _region.text.trim().isEmpty ? null : _region.text.trim().toUpperCase(),
        sellerRegistered: _registered,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _errors = failure is ValidationFailure ? failure.fieldErrors : const {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const AppAppBar(title: 'Calculation preferences'),
      body: BlocConsumer<TaxSettingsCubit, TaxSettingsState>(
        listenWhen: (a, b) => a.messageSerial != b.messageSerial && b.message != null,
        listener: (context, state) => showAppMessage(context, state.message!),
        builder: (context, state) {
          if (state.status != ViewStatus.loaded) {
            return const LoadingIndicator();
          }
          if (!_filled) {
            _filled = true;
            _country.text = state.preferences.countryCode ?? '';
            _region.text = state.preferences.regionCode ?? '';
            _registered = state.preferences.sellerRegistered;
          }
          return AppContentWidth(
            child: ListView(
              padding: AppSpacing.page,
              children: [
                Text(
                  'Tell Inventrix where your business is. Rules for a specific '
                  'state or country, and tax that differs between a sale '
                  'within your state and one to another state, depend on it.',
                  style: theme.textTheme.bodyMedium,
                ),
                AppSpacing.gap16,
                AppTextField(label: 'Country code', hint: 'IN', controller: _country, errorText: _errors['countryCode'], textCapitalization: TextCapitalization.characters),
                AppSpacing.gap12,
                AppTextField(label: 'State or region code (optional)', hint: 'KA', controller: _region, errorText: _errors['regionCode'], textCapitalization: TextCapitalization.characters),
                AppSpacing.gap12,
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('My business is registered for this tax'),
                  subtitle: const Text('Turn off if you do not charge tax on your sales. Sales are then recorded without tax.'),
                  value: _registered,
                  onChanged: (v) => setState(() => _registered = v),
                ),
                AppSpacing.gap16,
                AppButton(label: 'Save', loading: _saving, expand: true, onPressed: _saving ? null : () => _save(context)),
                AppSpacing.gap16,
                Text(
                  'Until customers have their own locations, the place of '
                  'supply is taken to be your own location.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
