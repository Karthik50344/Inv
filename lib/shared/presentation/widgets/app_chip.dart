import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// A selectable filter chip ("All items 1,420", "Low stock 8").
///
/// For a non-interactive status label use `AppBadge`.
class AppChip extends StatelessWidget {
  /// Creates a chip.
  const AppChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.icon,
    super.key,
  });

  /// Text.
  final String label;

  /// Whether it is the active filter.
  final bool selected;

  /// Called with the new selection state.
  final ValueChanged<bool>? onSelected;

  /// Optional count shown in a small pill.
  final int? count;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ChoiceChip(
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), AppSpacing.hGap4],
          Text(label),
          if (count != null) ...[
            AppSpacing.hGap8,
            DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? colors.brand.solid : colors.neutral.container,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? colors.brand.onSolid
                        : colors.neutral.onContainer,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
