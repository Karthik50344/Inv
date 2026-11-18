import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Pull-to-refresh with the app colors.
///
/// The [child] must be scrollable even when its content is short, otherwise
/// the gesture never starts: give lists `physics: AppRefreshIndicator.physics`.
class AppRefreshIndicator extends StatelessWidget {
  /// Creates the indicator.
  const AppRefreshIndicator({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  /// Reloads the data; the spinner shows until the future completes.
  final Future<void> Function() onRefresh;

  /// A scrollable.
  final Widget child;

  /// Scroll physics that always allow the pull gesture.
  static const ScrollPhysics physics = AlwaysScrollableScrollPhysics();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primaryText,
      backgroundColor: colors.surfaceElevated,
      child: child,
    );
  }
}
