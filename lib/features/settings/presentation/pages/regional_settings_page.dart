import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/settings/domain/entities/currency_option.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Currency, decimal places, date style and number style.
class RegionalSettingsPage extends StatefulWidget {
  /// Creates the page.
  const RegionalSettingsPage({super.key});

  @override
  State<RegionalSettingsPage> createState() => _RegionalSettingsPageState();
}

class _RegionalSettingsPageState extends State<RegionalSettingsPage> {
  late final TextEditingController _code;
  late int _places;

  @override
  void initState() {
    super.initState();
    final currency = context.read<SettingsCubit>().state.currency;
    _code = TextEditingController(text: currency.currencyCode);
    _places = currency.decimalPlaces;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _choose(CurrencyOption option) => setState(() {
    _code.text = option.code;
    _places = option.decimalPlaces;
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) =>
          b.message != null && a.messageSerial != b.messageSerial,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final locked = state.moneyLock.isLocked;
        final prefs = state.preferences;
        final sample = state.currency.fromMinor(123456789);
        final theme = Theme.of(context);
        final tokens = context.appColors;
        return Scaffold(
          appBar: const AppAppBar(title: 'Currency and formats'),
          body: AppContentWidth(child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppSpacing.page,
            children: [
              const AppSectionHeader(
                title: 'Currency',
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  0,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
              ),
              if (locked) ...[
                AppCard(
                  tone: AppTone.warning,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 20),
                      AppSpacing.hGap12,
                      Expanded(
                        child: Text(
                          'Locked: ${state.moneyLock.reason}. Existing '
                          'documents keep their own currency.',
                          key: const Key('currency_locked'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gap12,
              ],
              AppDropdown<String>(
                key: const Key('currency_pick'),
                label: 'Common currencies',
                value: CurrencyCatalog.find(_code.text)?.code,
                onChanged: locked
                    ? null
                    : (code) {
                        final option = code == null
                            ? null
                            : CurrencyCatalog.find(code);
                        if (option != null) {
                          _choose(option);
                        }
                      },
                items: [
                  for (final o in CurrencyCatalog.common)
                    AppDropdownItem(value: o.code, label: o.label),
                ],
              ),
              AppSpacing.gap12,
              AppTextField(
                key: const Key('currency_code'),
                controller: _code,
                enabled: !locked,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                label: 'Currency code',
                errorText: state.fieldErrors['code'],
              ),
              AppSpacing.gap12,
              AppDropdown<int>(
                key: const Key('currency_places'),
                label: 'Decimal places',
                value: _places,
                errorText: state.fieldErrors['decimalPlaces'],
                onChanged: locked
                    ? null
                    : (v) => setState(() => _places = v ?? _places),
                items: [
                  for (var i = 0; i <= 4; i++)
                    AppDropdownItem(value: i, label: '$i'),
                ],
              ),
              AppSpacing.gap16,
              AppButton(
                key: const Key('currency_save'),
                label: 'Save currency',
                icon: Icons.check,
                expand: true,
                loading: state.saving,
                onPressed: locked || state.saving
                    ? null
                    : () => cubit.saveCurrency(
                        code: _code.text,
                        decimalPlaces: _places,
                      ),
              ),
              const AppSectionHeader(
                title: 'Formats',
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s24,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
              ),
              AppDropdown<DateStyle>(
                key: const Key('format_date'),
                label: 'Date',
                value: prefs.dateStyle,
                onChanged: (v) {
                  if (v != null) {
                    cubit.setDateStyle(v);
                  }
                },
                items: [
                  for (final s in DateStyle.values)
                    AppDropdownItem(value: s, label: s.label),
                ],
              ),
              AppSpacing.gap12,
              AppDropdown<NumberStyle>(
                key: const Key('format_number'),
                label: 'Numbers',
                value: prefs.numberStyle,
                onChanged: (v) {
                  if (v != null) {
                    cubit.setNumberStyle(v);
                  }
                },
                items: [
                  for (final s in NumberStyle.values)
                    AppDropdownItem(value: s, label: s.label),
                ],
              ),
              AppSpacing.gap12,
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, color: tokens.textSecondary),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Text(
                        'Example: ${const MoneyFormatter().format(sample)} · '
                        '${DateFormatter.date(DateTime.utc(2026, 11, 15))}',
                        key: const Key('format_example'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )),
        );
      },
    );
  }
}
