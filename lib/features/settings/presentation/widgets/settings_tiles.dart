import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// A titled card that holds a stack of settings rows separated by dividers.
class SettingsGroup extends StatelessWidget {
  /// Creates the group.
  const SettingsGroup({required this.title, required this.children, super.key});

  /// Heading above the card.
  final String title;

  /// The rows ([SettingsTile], [SettingsSwitchTile] or any widget).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = context.appColors.divider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s20,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: AppRadius.cardRadius,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 64, color: divider),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded icon tile used as the leading element of settings rows.
class SettingsIcon extends StatelessWidget {
  /// Creates the icon tile.
  const SettingsIcon(this.icon, {this.tone = AppTone.brand, super.key});

  /// The icon.
  final IconData icon;

  /// Color meaning of the tile.
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = tone.colors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: colors.onContainer),
      ),
    );
  }
}

/// A tappable settings row: icon, title, optional summary and a chevron.
class SettingsTile extends StatelessWidget {
  /// Creates the row.
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tone = AppTone.brand,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Row title.
  final String title;

  /// Short summary of the current value.
  final String? subtitle;

  /// Color meaning of the icon tile.
  final AppTone tone;

  /// Opens the detail screen.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s4,
      ),
      leading: SettingsIcon(icon, tone: tone),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(Icons.chevron_right, color: tokens.textSecondary),
      onTap: onTap,
    );
  }
}

/// A settings row with a switch.
class SettingsSwitchTile extends StatelessWidget {
  /// Creates the row.
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.tone = AppTone.brand,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Row title.
  final String title;

  /// Explanation under the title.
  final String? subtitle;

  /// Color meaning of the icon tile.
  final AppTone tone;

  /// Current state.
  final bool value;

  /// Called with the new state.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s4,
      ),
      secondary: SettingsIcon(icon, tone: tone),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
