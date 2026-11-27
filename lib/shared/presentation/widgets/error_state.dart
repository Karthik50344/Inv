import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_button.dart';

/// Error placeholder with a message and, optionally, a retry button.
class ErrorState extends StatelessWidget {
  /// Creates the placeholder.
  const ErrorState({required this.message, this.onRetry, super.key});

  /// What went wrong, in plain language.
  final String message;

  /// Called by the retry button; the button is hidden when null.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = context.appColors.danger;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: danger.container,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Icon(
                    Icons.error_outline,
                    size: 32,
                    color: danger.onContainer,
                  ),
                ),
              ),
              AppSpacing.gap16,
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                AppSpacing.gap16,
                AppButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  variant: AppButtonVariant.secondary,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
