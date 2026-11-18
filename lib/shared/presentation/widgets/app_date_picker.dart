import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';

/// Opens the Material date picker, themed by the app.
///
/// Returns the chosen day, or null when cancelled. [first] defaults to ten
/// years back and [last] to ten years ahead.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? first,
  DateTime? last,
  String? helpText,
}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 10),
    lastDate: last ?? DateTime(now.year + 10, 12, 31),
    helpText: helpText,
  );
}

/// Opens the Material date-range picker, themed by the app.
Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  DateTimeRange? initial,
  DateTime? first,
  DateTime? last,
  String? helpText,
}) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    initialDateRange: initial,
    firstDate: first ?? DateTime(now.year - 10),
    lastDate: last ?? DateTime(now.year + 10, 12, 31),
    helpText: helpText,
  );
}

/// A form-style field that shows a date in the user's chosen date style and
/// opens the picker on tap.
class AppDatePickerField extends StatelessWidget {
  /// Creates the field.
  const AppDatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.first,
    this.last,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  /// Field label.
  final String label;

  /// The chosen date, or null when empty.
  final DateTime? value;

  /// Called with the picked date.
  final ValueChanged<DateTime> onChanged;

  /// Earliest selectable date.
  final DateTime? first;

  /// Latest selectable date.
  final DateTime? last;

  /// Forced error text.
  final String? errorText;

  /// Disables the field.
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final picked = await showAppDatePicker(
      context,
      initial: value,
      first: first,
      last: last,
      helpText: label,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = value;
    return Semantics(
      button: true,
      enabled: enabled,
      label: shown == null
          ? label
          : '$label, ${DateFormatter.date(shown)}',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: AppRadius.controlRadius,
          onTap: enabled ? () => _pick(context) : null,
          child: InputDecorator(
            isEmpty: shown == null,
            decoration: InputDecoration(
              labelText: label,
              errorText: errorText,
              enabled: enabled,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(
              shown == null ? '' : DateFormatter.date(shown),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
