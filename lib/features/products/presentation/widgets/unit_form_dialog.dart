import 'package:flutter/material.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';

/// Create/edit dialog for a unit of measurement.
class UnitFormDialog extends StatefulWidget {
  /// Creates the dialog; pass [unit] to edit.
  const UnitFormDialog({required this.onSubmit, this.unit, super.key});

  /// Unit being edited, or `null` to create.
  final UnitOfMeasure? unit;

  /// Saves the entered values.
  final Future<Result<UnitOfMeasure>> Function(
    String name,
    String symbol,
    int decimalPlaces,
  )
  onSubmit;

  @override
  State<UnitFormDialog> createState() => _UnitFormDialogState();
}

class _UnitFormDialogState extends State<UnitFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _symbol;
  late int _decimalPlaces;
  Map<String, String> _errors = const {};
  String? _message;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.unit?.name ?? '');
    _symbol = TextEditingController(text: widget.unit?.symbol ?? '');
    _decimalPlaces = widget.unit?.decimalPlaces ?? 0;
  }

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = const {};
      _message = null;
    });
    final result = await widget.onSubmit(
      _name.text,
      _symbol.text,
      _decimalPlaces,
    );
    if (!mounted) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
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
      title: Text(widget.unit == null ? 'New unit' : 'Edit unit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('unit_name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name *',
                errorText: _errors['name'],
              ),
            ),
            TextField(
              key: const Key('unit_symbol'),
              controller: _symbol,
              decoration: InputDecoration(
                labelText: 'Symbol *',
                errorText: _errors['symbol'],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('unit_decimals'),
              initialValue: _decimalPlaces,
              decoration: InputDecoration(
                labelText: 'Decimal places',
                helperText: 'Precision allowed for quantities in this unit.',
                errorText: _errors['decimalPlaces'],
              ),
              items: [
                for (var i = 0; i <= 3; i++)
                  DropdownMenuItem(value: i, child: Text('$i')),
              ],
              onChanged: (value) =>
                  setState(() => _decimalPlaces = value ?? _decimalPlaces),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('unit_save'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
