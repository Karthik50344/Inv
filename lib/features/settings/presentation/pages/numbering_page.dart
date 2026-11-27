import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
      builder: (dialog) => AppFormDialog(
        title: 'Next ${kind.label.toLowerCase()} number',
        saveKey: const Key('next_number_save'),
        saveLabel: 'Set',
        onSave: () => Navigator.of(dialog).pop(controller.text),
        children: [
          AppTextField(
            key: const Key('next_number_input'),
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            label: 'Next number',
            helper: 'Numbers already used cannot be reused.',
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
        final theme = Theme.of(context);
        return Scaffold(
          appBar: const AppAppBar(title: 'Document numbering'),
          body: AppContentWidth(child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: AppSpacing.page,
            children: [
              AppCard(
                tone: AppTone.info,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Text(
                        'Prefixes apply to documents posted from now on. '
                        'Numbers already issued never change, and counters '
                        'never go back.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const AppSectionHeader(
                title: 'Prefixes',
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s20,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
              ),
              for (final kind in DocumentKind.values) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        key: Key('prefix_${kind.sequenceKey}'),
                        controller: _prefixes[kind],
                        label: kind.label,
                        helper: 'Next: ${numbering.preview(kind)}',
                        errorText:
                            state.fieldErrors['prefix.${kind.sequenceKey}'],
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    AppSpacing.hGap4,
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s4),
                      child: AppIconButton(
                        key: Key('next_${kind.sequenceKey}'),
                        tooltip: 'Set next number',
                        icon: Icons.edit_outlined,
                        onPressed: () => _setNext(cubit, kind),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gap12,
              ],
              AppDropdown<int>(
                key: const Key('numbering_padding'),
                label: 'Digits in the number',
                value: _padding,
                errorText: state.fieldErrors['padding'],
                onChanged: (v) => setState(() => _padding = v ?? _padding),
                items: [
                  for (
                    var i = DocumentNumber.minWidth;
                    i <= DocumentNumber.maxWidth;
                    i++
                  )
                    AppDropdownItem(value: i, label: '$i'),
                ],
              ),
              AppSpacing.gap16,
              AppButton(
                key: const Key('numbering_save'),
                label: 'Save',
                icon: Icons.check,
                expand: true,
                loading: state.saving,
                onPressed: state.saving
                    ? null
                    : () => cubit.saveNumbering(
                        prefixes: {
                          for (final e in _prefixes.entries)
                            e.key: e.value.text,
                        },
                        padding: _padding,
                      ),
              ),
            ],
          )),
        );
      },
    );
  }
}
