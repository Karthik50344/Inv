import 'package:flutter/material.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';

/// Create/edit dialog for a category.
///
/// [onSubmit] performs the save and returns its [Result]; field errors are
/// shown inline and the dialog closes only on success.
class CategoryFormDialog extends StatefulWidget {
  /// Creates the dialog; pass [category] to edit.
  const CategoryFormDialog({required this.onSubmit, this.category, super.key});

  /// Category being edited, or `null` to create.
  final Category? category;

  /// Saves the entered values.
  final Future<Result<Category>> Function(String name, String? description)
  onSubmit;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  Map<String, String> _errors = const {};
  String? _message;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _description = TextEditingController(
      text: widget.category?.description ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = const {};
      _message = null;
    });
    final result = await widget.onSubmit(_name.text, _description.text);
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
      title: Text(widget.category == null ? 'New category' : 'Edit category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('category_name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name *',
                errorText: _errors['name'],
              ),
            ),
            TextField(
              key: const Key('category_description'),
              controller: _description,
              decoration: InputDecoration(
                labelText: 'Description',
                errorText: _errors['description'],
              ),
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
          key: const Key('category_save'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
