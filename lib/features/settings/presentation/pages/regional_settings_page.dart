import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/settings/domain/entities/currency_option.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';

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
        return Scaffold(
          appBar: AppBar(title: const Text('Currency and formats')),
          body: ListView(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            children: [
              Text('Currency', style: Theme.of(context).textTheme.titleMedium),
              if (locked)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Locked: ${state.moneyLock.reason}. Existing documents '
                    'keep their own currency.',
                    key: const Key('currency_locked'),
                  ),
                ),
              DropdownButtonFormField<String>(
                key: const Key('currency_pick'),
                initialValue: CurrencyCatalog.find(_code.text)?.code,
                decoration: const InputDecoration(
                  labelText: 'Common currencies',
                ),
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
                    DropdownMenuItem(value: o.code, child: Text(o.label)),
                ],
              ),
              TextField(
                key: const Key('currency_code'),
                controller: _code,
                enabled: !locked,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                decoration: InputDecoration(
                  labelText: 'Currency code',
                  errorText: state.fieldErrors['code'],
                ),
              ),
              DropdownButtonFormField<int>(
                key: const Key('currency_places'),
                initialValue: _places,
                decoration: InputDecoration(
                  labelText: 'Decimal places',
                  errorText: state.fieldErrors['decimalPlaces'],
                ),
                onChanged: locked
                    ? null
                    : (v) => setState(() => _places = v ?? _places),
                items: [
                  for (var i = 0; i <= 4; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              FilledButton(
                key: const Key('currency_save'),
                onPressed: locked || state.saving
                    ? null
                    : () => cubit.saveCurrency(
                        code: _code.text,
                        decimalPlaces: _places,
                      ),
                child: const Text('Save currency'),
              ),
              const Divider(height: 40),
              Text('Formats', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                trailing: DropdownButton<DateStyle>(
                  key: const Key('format_date'),
                  value: prefs.dateStyle,
                  onChanged: (v) {
                    if (v != null) {
                      cubit.setDateStyle(v);
                    }
                  },
                  items: [
                    for (final s in DateStyle.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Numbers'),
                trailing: DropdownButton<NumberStyle>(
                  key: const Key('format_number'),
                  value: prefs.numberStyle,
                  onChanged: (v) {
                    if (v != null) {
                      cubit.setNumberStyle(v);
                    }
                  },
                  items: [
                    for (final s in NumberStyle.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                ),
              ),
              Text(
                'Example: ${const MoneyFormatter().format(sample)} · '
                '${DateFormatter.date(DateTime.utc(2026, 11, 15))}',
                key: const Key('format_example'),
              ),
            ],
          ),
        );
      },
    );
  }
}
