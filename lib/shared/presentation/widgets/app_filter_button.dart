import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Opens a filter sheet; shows how many filters are active.
class AppFilterButton extends StatelessWidget {
  /// Creates the button.
  const AppFilterButton({
    required this.onPressed,
    this.activeCount = 0,
    this.tooltip = 'Filters',
    super.key,
  });

  /// Called on tap, usually to open a filter bottom sheet.
  final VoidCallback? onPressed;

  /// Number of active filters; a badge shows when above zero.
  final int activeCount;

  /// Hint and screen-reader label.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final brand = context.appColors.brand;
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: activeCount > 0 ? '$tooltip ($activeCount active)' : tooltip,
      icon: Badge(
        isLabelVisible: activeCount > 0,
        label: Text('$activeCount'),
        backgroundColor: brand.solid,
        textColor: brand.onSolid,
        child: const Icon(Icons.tune),
      ),
    );
  }
}
