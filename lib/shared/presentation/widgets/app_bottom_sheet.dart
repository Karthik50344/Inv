import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_spacing.dart';

/// Shows a modal bottom sheet with the app look and returns what it pops.
///
/// The sheet grows with its content up to the screen height, scrolls when it
/// is taller, rises above the keyboard, and is capped at 640 px wide on
/// tablets. [title] is optional; pass your own header in [builder] instead if
/// you need one.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) =>
        AppBottomSheet(title: title, subtitle: subtitle, child: builder(sheetContext)),
  );
}

/// Content frame of a bottom sheet: optional title, scrollable body, keyboard
/// padding. Used by [showAppBottomSheet].
class AppBottomSheet extends StatelessWidget {
  /// Creates the frame.
  const AppBottomSheet({
    required this.child,
    this.title,
    this.subtitle,
    super.key,
  });

  /// Body.
  final Widget child;

  /// Optional heading.
  final String? title;

  /// Optional line under the heading.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s4,
                AppSpacing.s24,
                AppSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title!, style: theme.textTheme.titleLarge),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s4,
                AppSpacing.s24,
                AppSpacing.s24,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
