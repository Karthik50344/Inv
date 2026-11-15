import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/constants/app_constants.dart';

/// Prominent reminder that all data lives on this device only.
class LocalDataWarningBanner extends StatelessWidget {
  /// Creates the banner.
  const LocalDataWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Text(
              AppConstants.localDataWarning,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
