import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/shared/presentation/widgets/app_button.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Frame shared by the small create/edit dialogs (unit, category, tax rate,
/// expense category).
///
/// It owns the layout only: the title, the scrollable [children] with even
/// spacing, an inline [message] for failures that do not belong to a field,
/// and the Cancel / Save buttons. The caller keeps its own controllers,
/// validation and save logic.
class AppFormDialog extends StatelessWidget {
  /// Creates the dialog frame.
  const AppFormDialog({
    required this.title,
    required this.children,
    required this.onSave,
    this.saveKey,
    this.saveLabel = 'Save',
    this.saving = false,
    this.message,
    this.cancelResult,
    super.key,
  });

  /// Headline.
  final String title;

  /// Form fields, stacked with 12 px between them.
  final List<Widget> children;

  /// Called by the save button. The button is disabled while [saving].
  final VoidCallback onSave;

  /// Key of the save button, for tests.
  final Key? saveKey;

  /// Text of the save button.
  final String saveLabel;

  /// Shows a spinner on the save button and disables both buttons.
  final bool saving;

  /// Failure text that is not tied to one field.
  final String? message;

  /// What Cancel pops with (callers differ: `false` or nothing).
  final Object? cancelResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = AppTone.danger.colors(context);
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A little room so floating labels are not clipped by the
              // scroll view.
              const SizedBox(height: AppSpacing.s4),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) AppSpacing.gap12,
                children[i],
              ],
              if (message != null) ...[
                AppSpacing.gap12,
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: danger.container,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    child: Text(
                      message!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: danger.onContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s8,
        AppSpacing.s24,
        AppSpacing.s20,
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          onPressed: saving
              ? null
              : () => Navigator.of(context).pop(cancelResult),
        ),
        AppButton(
          key: saveKey,
          label: saveLabel,
          loading: saving,
          onPressed: saving ? null : onSave,
        ),
      ],
    );
  }
}
