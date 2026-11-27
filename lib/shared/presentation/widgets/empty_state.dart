import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Placeholder for a list or screen with nothing to show: an icon in a soft
/// tile, a title, an optional explanation and an optional action.
class EmptyState extends StatelessWidget {
  /// Creates the placeholder.
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  /// Large icon shown above the title.
  final IconData icon;

  /// Short headline, for example "No products yet".
  final String title;

  /// Optional explanation or hint.
  final String? message;

  /// Optional call to action, such as an "Add" button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
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
                  color: colors.neutral.container,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Icon(icon, size: 32, color: colors.textSecondary),
                ),
              ),
              AppSpacing.gap16,
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                AppSpacing.gap8,
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[AppSpacing.gap16, action!],
            ],
          ),
        ),
      ),
    );
  }
}
