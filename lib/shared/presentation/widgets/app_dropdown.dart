import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_radius.dart';

/// One choice of an [AppDropdown].
class AppDropdownItem<T> {
  /// Creates a choice.
  const AppDropdownItem({required this.value, required this.label});

  /// The value reported when chosen.
  final T value;

  /// Text shown for it.
  final String label;
}

/// A form dropdown with the app look.
///
/// Rebuilds its inner field when [value] changes from outside, so it can be
/// driven by a BLoC state like any other controlled input.
class AppDropdown<T> extends StatelessWidget {
  /// Creates a dropdown.
  const AppDropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.validator,
    this.prefixIcon,
    this.helper,
    this.errorText,
    super.key,
  });

  /// The choices.
  final List<AppDropdownItem<T>> items;

  /// Called with the chosen value; null disables the dropdown.
  final ValueChanged<T?>? onChanged;

  /// The selected value.
  final T? value;

  /// Floating label.
  final String? label;

  /// Placeholder.
  final String? hint;

  /// Form validator.
  final FormFieldValidator<T>? validator;

  /// Icon at the start.
  final IconData? prefixIcon;

  /// Small explanation under the field.
  final String? helper;

  /// Error shown under the field (for screens that validate without a
  /// `Form`).
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      isExpanded: true,
      validator: validator,
      onChanged: onChanged,
      borderRadius: AppRadius.controlRadius,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item.value,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
  }
}
