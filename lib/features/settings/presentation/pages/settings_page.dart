import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

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
          appBar: AppBar(title: const Text('Settings')),
          body: switch (state.status) {
            ViewStatus.initial ||
            ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the settings.',
              onRetry: cubit.load,
            ),
            _ => _content(context, state, cubit),
          },
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
      children: [
        const _Header('Business'),
        ListTile(
          key: const Key('settings_business'),
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Business profile'),
          subtitle: Text(state.business?.name ?? 'Not set up yet'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(RouteNames.settingsBusiness),
        ),
        ListTile(
          key: const Key('settings_regional'),
          leading: const Icon(Icons.language_outlined),
          title: const Text('Currency and formats'),
          subtitle: Text(
            '${state.currency.currencyCode} · '
            '${prefs.dateStyle.label} · ${prefs.numberStyle.label}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(RouteNames.settingsRegional),
        ),
        const _Header('Sales and purchases'),
        ListTile(
          key: const Key('settings_tax'),
          leading: const Icon(Icons.percent),
          title: const Text('Tax rates'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(RouteNames.taxRates),
        ),
        ListTile(
          key: const Key('settings_numbering'),
          leading: const Icon(Icons.tag),
          title: const Text('Document numbering'),
          subtitle: Text(
            'Next invoice: ${state.numbering.preview(DocumentKind.salesInvoice)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(RouteNames.settingsNumbering),
        ),
        ListTile(
          key: const Key('settings_methods'),
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Payment methods'),
          subtitle: const Text('Add methods and choose the default'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(RouteNames.paymentMethods),
        ),
        SwitchListTile(
          key: const Key('settings_sales_approval'),
          secondary: const Icon(Icons.verified_outlined),
          title: const Text('Require approval for sales'),
          subtitle: const Text('Invoices must be approved before posting.'),
          value: prefs.salesApprovalRequired,
          onChanged: (v) => cubit.setSalesApproval(required: v),
        ),
        SwitchListTile(
          key: const Key('settings_purchase_approval'),
          secondary: const Icon(Icons.fact_check_outlined),
          title: const Text('Require approval for purchases'),
          subtitle: const Text('Purchases must be approved before posting.'),
          value: prefs.purchaseApprovalRequired,
          onChanged: (v) => cubit.setPurchaseApproval(required: v),
        ),
        const _Header('App'),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Theme'),
          trailing: DropdownButton<ThemePreference>(
            key: const Key('settings_theme'),
            value: prefs.theme,
            onChanged: (v) {
              if (v != null) {
                cubit.setTheme(v);
              }
            },
            items: [
              for (final t in ThemePreference.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Backup reminder'),
          subtitle: const Text('Remind me to export a backup'),
          trailing: DropdownButton<int>(
            key: const Key('settings_reminder'),
            value: prefs.backupReminderDays,
            onChanged: (v) {
              if (v != null) {
                cubit.setBackupReminderDays(v);
              }
            },
            items: [
              for (final d in AppPreferences.reminderChoices)
                DropdownMenuItem(
                  value: d,
                  child: Text(d == 0 ? 'Off' : 'Every $d days'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
