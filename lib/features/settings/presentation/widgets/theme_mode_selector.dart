import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

/// Three-way System / Light / Dark choice for the app theme.
///
/// It only reports the choice; the settings cubit saves it and the app
/// rebuilds with the new theme immediately.
class ThemeModeSelector extends StatelessWidget {
  /// Creates the selector.
  const ThemeModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The current preference.
  final ThemePreference value;

  /// Called with the newly chosen preference.
  final ValueChanged<ThemePreference> onChanged;

  static const Map<ThemePreference, (String, IconData)> _options =
      <ThemePreference, (String, IconData)>{
        ThemePreference.system: ('System', Icons.brightness_auto_outlined),
        ThemePreference.light: ('Light', Icons.light_mode_outlined),
        ThemePreference.dark: ('Dark', Icons.dark_mode_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              AppSpacing.hGap16,
              Expanded(
                child: Text(
                  'Theme',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
          AppSpacing.gap12,
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemePreference>(
              key: const Key('settings_theme'),
              showSelectedIcon: false,
              segments: [
                for (final entry in _options.entries)
                  ButtonSegment<ThemePreference>(
                    value: entry.key,
                    icon: Icon(entry.value.$2),
                    label: Text(entry.value.$1),
                  ),
              ],
              selected: <ThemePreference>{value},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
