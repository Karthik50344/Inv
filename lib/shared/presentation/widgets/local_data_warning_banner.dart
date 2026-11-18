import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Reminder that data lives only on this device and should be backed up.
class LocalDataWarningBanner extends StatelessWidget {
  /// Creates the banner.
  const LocalDataWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppTone.warning.colors(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: AppRadius.controlRadius,
        border: Border.all(color: colors.solid.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.onContainer),
            AppSpacing.hGap12,
            Expanded(
              child: Text(
                AppConstants.localDataWarning,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.onContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
