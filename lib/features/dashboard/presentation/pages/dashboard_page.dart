import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/local_data_warning_banner.dart';

/// Placeholder dashboard; real metrics arrive in Phase 9.
class DashboardPage extends StatelessWidget {
  /// Creates the page.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        children: [
          Text(
            'Welcome to ${AppConstants.appName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          const LocalDataWarningBanner(),
          const SizedBox(height: AppDimensions.spaceLg),
          const EmptyState(
            icon: Icons.insights_outlined,
            title: 'No data yet',
            message:
                'Sales, stock and balance summaries will appear here '
                'once you start recording business activity.',
          ),
        ],
      ),
    );
  }
}
