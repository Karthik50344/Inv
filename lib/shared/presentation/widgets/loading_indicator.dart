import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Centered spinner shown while a screen loads, with an optional message.
class LoadingIndicator extends StatelessWidget {
  /// Creates the indicator.
  const LoadingIndicator({this.message, super.key});

  /// Optional text under the spinner ("Loading products").
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            AppSpacing.gap16,
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
