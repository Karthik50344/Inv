import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// A form text field with the app look (filled, 3:1 border, brand focus ring).
///
/// Thin wrapper over [TextFormField], so validation, controllers and form
/// keys work as usual. Keyboard friendly: single-line fields move to the next
/// field on "next", multi-line fields insert a new line.
class AppTextField extends StatelessWidget {
  /// Creates a text field.
  const AppTextField({
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.prefixIcon,
    this.prefixText,
    this.suffixText,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.autovalidateMode,
    this.autofillHints,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    super.key,
  });

  /// Label that floats above the value.
  final String? label;

  /// Placeholder.
  final String? hint;

  /// Help text under the field.
  final String? helper;

  /// Forced error text.
  final String? errorText;

  /// Text controller.
  final TextEditingController? controller;

  /// Initial text when no [controller] is given.
  final String? initialValue;

  /// Focus node.
  final FocusNode? focusNode;

  /// Icon at the start.
  final IconData? prefixIcon;

  /// Text before the value (for example a currency symbol).
  final String? prefixText;

  /// Text after the value (for example a unit).
  final String? suffixText;

  /// Widget at the end (for example a scan or clear button).
  final Widget? suffix;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Action key; defaults to next, or newline for multi-line fields.
  final TextInputAction? textInputAction;

  /// Capitalization.
  final TextCapitalization textCapitalization;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Form validator.
  final FormFieldValidator<String>? validator;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the action key is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Called on tap (useful with [readOnly] pickers).
  final VoidCallback? onTap;

  /// When to validate.
  final AutovalidateMode? autovalidateMode;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Hides the text.
  final bool obscureText;

  /// Prevents editing.
  final bool readOnly;

  /// Disables the field.
  final bool enabled;

  /// Focuses the field when it first appears.
  final bool autofocus;

  /// Minimum visible lines.
  final int? minLines;

  /// Maximum visible lines; null grows without limit.
  final int? maxLines;

  /// Maximum characters.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines != 1;
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      keyboardType: multiline ? TextInputType.multiline : keyboardType,
      textInputAction:
          textInputAction ??
          (multiline ? TextInputAction.newline : TextInputAction.next),
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      autovalidateMode: autovalidateMode,
      autofillHints: autofillHints,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        prefixText: prefixText,
        suffixText: suffixText,
        suffixIcon: suffix,
      ),
    );
  }
}
