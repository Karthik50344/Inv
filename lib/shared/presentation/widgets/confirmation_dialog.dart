import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_button.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Asks the user to confirm an action and returns their answer.
///
/// Resolves to `true` only when the confirm button is pressed; dismissing the
/// dialog or pressing cancel gives `false`. A [destructive] action gets a red
/// confirm button and a warning icon.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return confirmed ?? false;
}

/// The dialog behind [showConfirmationDialog]. Pops with `true` or `false`.
class AppConfirmationDialog extends StatelessWidget {
  /// Creates the dialog.
  const AppConfirmationDialog({
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    super.key,
  });

  /// Headline.
  final String title;

  /// Explanation of what will happen.
  final String message;

  /// Text of the confirm button.
  final String confirmLabel;

  /// Text of the cancel button.
  final String cancelLabel;

  /// Styles the dialog as a dangerous action.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tone = destructive ? AppTone.danger : AppTone.brand;
    final colors = tone.colors(context);
    return AlertDialog(
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.container,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            destructive ? Icons.warning_amber_rounded : Icons.help_outline,
            color: colors.onContainer,
          ),
        ),
      ),
      iconPadding: const EdgeInsets.only(top: 24),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowButtonSpacing: 8,
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.outlined,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: confirmLabel,
          variant: destructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
