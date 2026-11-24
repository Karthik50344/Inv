import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/presentation/bloc/tax_settings_cubit.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// The tax settings home: what is set up, what is missing, and the way to
/// every tax list.
class TaxSettingsPage extends StatelessWidget {
  /// Creates the page.
  const TaxSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Tax settings'),
      body: BlocConsumer<TaxSettingsCubit, TaxSettingsState>(
        listenWhen: (a, b) => a.messageSerial != b.messageSerial && b.message != null,
        listener: (context, state) => showAppMessage(context, state.message!),
        builder: (context, state) {
          switch (state.status) {
            case ViewStatus.initial:
            case ViewStatus.loading:
              return const LoadingIndicator();
            case ViewStatus.failure:
            case ViewStatus.empty:
              return ErrorState(
                message: state.error ?? 'Could not load the tax settings.',
                onRetry: () => context.read<TaxSettingsCubit>().load(),
              );
            case ViewStatus.loaded:
              return _Content(config: state.configuration!, preferences: state.preferences);
          }
        },
      ),
    );
  }
}

/// Things worth fixing before invoices are made.
List<String> taxSetupWarnings(TaxConfiguration c, TaxPreferences p) {
  final warnings = <String>[];
  if (c.regimes.isEmpty) {
    warnings.add('No tax system is set up. Start with "Tax systems".');
  }
  if (c.regimes.isNotEmpty && c.defaultProfile == null) {
    warnings.add('No tax profile is in use. Add one under "Tax profiles".');
  }
  for (final category in c.categories) {
    if (!category.isActive || !category.defaultTaxTreatment.computesTax) {
      continue;
    }
    final rules = c.rules.where((r) => r.isActive && r.taxCategoryId == category.id);
    if (rules.isEmpty) {
      warnings.add('"${category.name}" charges tax but has no rule, so documents using it cannot be taxed.');
    }
  }
  for (final rule in c.rules) {
    if (rule.isActive && c.componentsOf(rule.id).isEmpty) {
      final name = c.category(rule.taxCategoryId)?.name ?? 'a category';
      warnings.add('A rule for "$name" has no tax lines, so it is ignored.');
    }
  }
  if (p.countryCode == null) {
    warnings.add('Your country is not set under "Calculation preferences". Rules for specific states or countries need it.');
  }
  return warnings;
}

class _Content extends StatelessWidget {
  const _Content({required this.config, required this.preferences});

  final TaxConfiguration config;
  final TaxPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warnings = taxSetupWarnings(config, preferences);
    final profile = config.defaultProfile;
    final regime = profile == null ? null : config.regime(profile.regimeId);

    Widget tile(IconData icon, String title, String subtitle, String path) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      child: AppCard(
        onTap: () async {
          await context.push(path);
          if (context.mounted) {
            await context.read<TaxSettingsCubit>().load();
          }
        },
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  AppSpacing.gap4,
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    return RefreshIndicator(
      onRefresh: () => context.read<TaxSettingsCubit>().load(),
      child: AppContentWidth(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('In use now', style: theme.textTheme.labelLarge),
                  AppSpacing.gap8,
                  Text(profile?.name ?? 'No tax profile yet', style: theme.textTheme.titleLarge),
                  if (regime != null) Text(regime.name, style: theme.textTheme.bodyMedium),
                  AppSpacing.gap8,
                  Text(
                    'Changes affect new documents only. Invoices already '
                    'posted keep the tax they were made with.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (warnings.isNotEmpty) ...[
              const AppSectionHeader(title: 'To check'),
              for (final w in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: AppCard(
                    tone: AppTone.warning,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(child: Text(w, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(child: Text('Your tax setup looks complete.', style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const AppSectionHeader(title: 'Set up'),
            tile(Icons.public, 'Tax systems', '${config.regimes.length} set up. For example GST or VAT.', RoutePaths.taxSystems),
            tile(Icons.badge_outlined, 'Tax profiles', '${config.profiles.length} set up. The set of rules in use.', RoutePaths.taxProfiles),
            tile(Icons.category_outlined, 'Tax categories', '${config.categories.length} set up. Products are given one.', RoutePaths.taxCategories),
            tile(Icons.rule, 'Tax rules', '${config.rules.length} set up. Rates, places and dates.', RoutePaths.taxRules),
            tile(Icons.map_outlined, 'Places', '${config.jurisdictions.length} set up. States, provinces, cities.', RoutePaths.taxPlaces),
            tile(Icons.swap_horiz, 'Product overrides', '${config.overrides.length} set up. A reasoned exception for a product.', RoutePaths.taxOverrides),
            tile(Icons.tune, 'Calculation preferences', preferences.countryCode == null ? 'Not set' : 'Based in ${preferences.countryCode}${preferences.regionCode == null ? '' : '-${preferences.regionCode}'}', RoutePaths.taxPreferences),
            AppSpacing.gap16,
            Text(
              'Inventrix does not come with tax rates and does not decide '
              'what the law requires. Enter the rates and rules your tax '
              'advisor gives you.',
              style: theme.textTheme.bodySmall,
            ),
            AppSpacing.gap24,
          ],
        ),
      ),
    );
  }
}
