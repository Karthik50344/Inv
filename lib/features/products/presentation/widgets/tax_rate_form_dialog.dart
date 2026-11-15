import 'package:flutter/material.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';

/// Dialog that creates a tax rate; pops with the created [TaxRate].
class TaxRateFormDialog extends StatefulWidget {
  /// Creates the dialog. [onSubmit] performs the save.
  const TaxRateFormDialog({required this.onSubmit, super.key});

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
  final TextEditingController _name = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  bool _exempt = false;
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
    return AlertDialog(
      title: const Text('New tax rate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('tax_name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name *',
                errorText: _errors['name'],
              ),
            ),
            TextField(
              key: const Key('tax_rate'),
              controller: _rate,
              enabled: !_exempt,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Rate (%)',
                errorText: _errors['ratePercent'],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax exempt'),
              value: _exempt,
              onChanged: (value) => setState(() => _exempt = value),
            ),
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('tax_save'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
