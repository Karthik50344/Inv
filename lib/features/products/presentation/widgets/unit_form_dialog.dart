import 'package:material_ui/material_ui.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
    return AppFormDialog(
      title: widget.unit == null ? 'New unit' : 'Edit unit',
      saveKey: const Key('unit_save'),
      saving: _saving,
      message: _message,
      cancelResult: false,
      onSave: _save,
      children: [
        AppTextField(
          key: const Key('unit_name'),
          controller: _name,
          autofocus: true,
          label: 'Name *',
          errorText: _errors['name'],
          textCapitalization: TextCapitalization.words,
        ),
        AppTextField(
          key: const Key('unit_symbol'),
          controller: _symbol,
          label: 'Symbol *',
          errorText: _errors['symbol'],
        ),
        AppDropdown<int>(
          key: const Key('unit_decimals'),
          label: 'Decimal places',
          helper: 'Precision allowed for quantities in this unit.',
          errorText: _errors['decimalPlaces'],
          value: _decimalPlaces,
          items: [
            for (var i = 0; i <= 3; i++) AppDropdownItem(value: i, label: '$i'),
          ],
          onChanged: (value) =>
              setState(() => _decimalPlaces = value ?? _decimalPlaces),
        ),
      ],
    );
  }
}
