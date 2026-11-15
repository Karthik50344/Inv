import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';

/// Error message with an optional retry button.
class ErrorState extends StatelessWidget {
  /// Creates an error state showing a user-safe [message].
  const ErrorState({required this.message, this.onRetry, super.key});

  /// User-safe description of what went wrong.
  final String message;

  /// Called when the user taps "Retry"; hides the button when null.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spaceMd),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
