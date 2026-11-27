import 'package:material_ui/material_ui.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Dialog that creates or edits a tax rate; pops with the saved [TaxRate].
///
/// Pass [initial] to edit an existing rate.
class TaxRateFormDialog extends StatefulWidget {
  /// Creates the dialog. [onSubmit] performs the save.
  const TaxRateFormDialog({required this.onSubmit, this.initial, super.key});

  /// The rate being edited, or `null` to create one.
  final TaxRate? initial;

  /// Saves the entered values.
  final Future<Result<TaxRate>> Function(
    String name,
    String ratePercent,
    bool isExempt,
  )
  onSubmit;

  @override
  State<TaxRateFormDialog> createState() => _TaxRateFormDialogState();
}

class _TaxRateFormDialogState extends State<TaxRateFormDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name,
  );
  late final TextEditingController _rate = TextEditingController(
    text: widget.initial == null || widget.initial!.isExempt
        ? null
        : widget.initial!.percentLabel,
  );
  late bool _exempt = widget.initial?.isExempt ?? false;
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = const {};
      _message = null;
    });
    final result = await widget.onSubmit(_name.text, _rate.text, _exempt);
    if (!mounted) {
      return;
    }
    final created = result.valueOrNull;
    if (created != null) {
      Navigator.of(context).pop(created);
      return;
    }
    final failure = result.failureOrNull!;
    setState(() {
      _saving = false;
      if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
        _errors = failure.fieldErrors;
      } else {
        _message = failure.userMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: widget.initial == null ? 'New tax rate' : 'Edit tax rate',
      saveKey: const Key('tax_save'),
      saving: _saving,
      message: _message,
      onSave: _save,
      children: [
        AppTextField(
          key: const Key('tax_name'),
          controller: _name,
          autofocus: true,
          label: 'Name *',
          errorText: _errors['name'],
          textCapitalization: TextCapitalization.words,
        ),
        AppTextField(
          key: const Key('tax_rate'),
          controller: _rate,
          enabled: !_exempt,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          label: 'Rate (%)',
          errorText: _errors['ratePercent'],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tax exempt'),
          value: _exempt,
          onChanged: (value) => setState(() => _exempt = value),
        ),
      ],
    );
  }
}
