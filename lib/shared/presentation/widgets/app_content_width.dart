import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';

/// Keeps page content at a readable width on tablets and landscape phones.
///
/// On phones it changes nothing. On wider screens the content is centered and
/// capped at [AppDimensions.maxContentWidth], while the app bar and page
/// background still span the full width.
class AppContentWidth extends StatelessWidget {
  /// Creates the wrapper.
  const AppContentWidth({
    required this.child,
    this.maxWidth = AppDimensions.maxContentWidth,
    super.key,
  });

  /// The page body.
  final Widget child;

  /// Widest the content may grow.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
