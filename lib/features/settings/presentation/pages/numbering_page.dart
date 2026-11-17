import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';

/// Prefix per document type, digit padding and the next number.
class NumberingPage extends StatefulWidget {
  /// Creates the page.
  const NumberingPage({super.key});

  @override
  State<NumberingPage> createState() => _NumberingPageState();
}

class _NumberingPageState extends State<NumberingPage> {
  final Map<DocumentKind, TextEditingController> _prefixes = {};
  late int _padding;

  @override
  void initState() {
    super.initState();
    final numbering = context.read<SettingsCubit>().state.numbering;
    _padding = numbering.padding;
    for (final kind in DocumentKind.values) {
      _prefixes[kind] = TextEditingController(text: numbering.prefixOf(kind));
    }
  }

  @override
  void dispose() {
    for (final c in _prefixes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _setNext(SettingsCubit cubit, DocumentKind kind) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Next ${kind.label.toLowerCase()} number'),
        content: TextField(
          key: const Key('next_number_input'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            helperText: 'Numbers already used cannot be reused.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('next_number_save'),
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null) {
      await cubit.setNextNumber(kind, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) =>
          b.message != null && a.messageSerial != b.messageSerial,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final numbering = state.numbering;
        return Scaffold(
          appBar: AppBar(title: const Text('Document numbering')),
          body: ListView(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            children: [
              Text(
                'Prefixes apply to documents posted from now on. Numbers '
                'already issued never change, and counters never go back.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              for (final kind in DocumentKind.values) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('prefix_${kind.sequenceKey}'),
                        controller: _prefixes[kind],
                        decoration: InputDecoration(
                          labelText: kind.label,
                          helperText: 'Next: ${numbering.preview(kind)}',
                          errorText:
                              state.fieldErrors['prefix.${kind.sequenceKey}'],
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('next_${kind.sequenceKey}'),
                      tooltip: 'Set next number',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _setNext(cubit, kind),
                    ),
                  ],
                ),
              ],
              DropdownButtonFormField<int>(
                key: const Key('numbering_padding'),
                initialValue: _padding,
                decoration: InputDecoration(
                  labelText: 'Digits in the number',
                  errorText: state.fieldErrors['padding'],
                ),
                onChanged: (v) => setState(() => _padding = v ?? _padding),
                items: [
                  for (
                    var i = DocumentNumber.minWidth;
                    i <= DocumentNumber.maxWidth;
                    i++
                  )
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              FilledButton(
                key: const Key('numbering_save'),
                onPressed: state.saving
                    ? null
                    : () => cubit.saveNumbering(
                        prefixes: {
                          for (final e in _prefixes.entries)
                            e.key: e.value.text,
                        },
                        padding: _padding,
                      ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}
