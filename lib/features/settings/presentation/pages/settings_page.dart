import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/features/settings/presentation/widgets/settings_tiles.dart';
import 'package:inventrix/features/settings/presentation/widgets/theme_mode_selector.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Home of the settings: links to the detail screens plus the switches that
/// need no screen of their own.
class SettingsPage extends StatefulWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) =>
          b.message != null && a.messageSerial != b.messageSerial,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        return Scaffold(
          appBar: const AppAppBar(title: 'Settings'),
          body: AppContentWidth(child: switch (state.status) {
            ViewStatus.initial ||
            ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the settings.',
              onRetry: cubit.load,
            ),
            _ => _content(context, state, cubit),
          }),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    SettingsState state,
    SettingsCubit cubit,
  ) {
    final prefs = state.preferences;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        SettingsGroup(
          title: 'Business',
          children: [
            SettingsTile(
              key: const Key('settings_business'),
              icon: Icons.storefront_outlined,
              title: 'Business profile',
              subtitle: state.business?.name ?? 'Not set up yet',
              onTap: () => context.pushNamed(RouteNames.settingsBusiness),
            ),
            SettingsTile(
              key: const Key('settings_regional'),
              icon: Icons.language_outlined,
              title: 'Currency and formats',
              subtitle:
                  '${state.currency.currencyCode} · '
                  '${prefs.dateStyle.label} · ${prefs.numberStyle.label}',
              onTap: () => context.pushNamed(RouteNames.settingsRegional),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Sales and purchases',
          children: [
            SettingsTile(
              key: const Key('settings_tax'),
              icon: Icons.percent,
              title: 'Tax rates',
              onTap: () => context.pushNamed(RouteNames.taxRates),
            ),
            SettingsTile(
              key: const Key('settings_numbering'),
              icon: Icons.tag,
              title: 'Document numbering',
              subtitle:
                  'Next invoice: '
                  '${state.numbering.preview(DocumentKind.salesInvoice)}',
              onTap: () => context.pushNamed(RouteNames.settingsNumbering),
            ),
            SettingsTile(
              key: const Key('settings_methods'),
              icon: Icons.payments_outlined,
              title: 'Payment methods',
              subtitle: 'Add methods and choose the default',
              onTap: () => context.pushNamed(RouteNames.paymentMethods),
            ),
            SettingsSwitchTile(
              key: const Key('settings_sales_approval'),
              icon: Icons.verified_outlined,
              title: 'Require approval for sales',
              subtitle: 'Invoices must be approved before posting.',
              value: prefs.salesApprovalRequired,
              onChanged: (v) => cubit.setSalesApproval(required: v),
            ),
            SettingsSwitchTile(
              key: const Key('settings_purchase_approval'),
              icon: Icons.fact_check_outlined,
              title: 'Require approval for purchases',
              subtitle: 'Purchases must be approved before posting.',
              value: prefs.purchaseApprovalRequired,
              onChanged: (v) => cubit.setPurchaseApproval(required: v),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Appearance',
          children: [
            ThemeModeSelector(value: prefs.theme, onChanged: cubit.setTheme),
          ],
        ),
        SettingsGroup(
          title: 'Help',
          children: [
            SettingsTile(
              key: const Key('settings_intro'),
              icon: Icons.slideshow_outlined,
              title: 'App introduction',
              subtitle: 'See the welcome slides again',
              onTap: () => context.pushNamed(RouteNames.intro),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Data',
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: AppDropdown<int>(
                key: const Key('settings_reminder'),
                label: 'Backup reminder',
                helper: 'Remind me to export a backup',
                prefixIcon: Icons.backup_outlined,
                value: prefs.backupReminderDays,
                items: [
                  for (final d in AppPreferences.reminderChoices)
                    AppDropdownItem(
                      value: d,
                      label: d == 0 ? 'Off' : 'Every $d days',
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    cubit.setBackupReminderDays(v);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
