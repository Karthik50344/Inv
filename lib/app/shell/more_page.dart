import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/more_destinations.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_app_bar.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';
import 'package:inventrix/shared/presentation/widgets/app_section_header.dart';

/// The "More" tab: everything outside the four main tabs, in three groups.
class MorePage extends StatelessWidget {
  /// Creates the page.
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'More'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.s24),
            children: [
              for (final group in MoreGroup.values) ...[
                AppSectionHeader(title: group.label),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageGutter,
                  ),
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: _tiles(
                        moreDestinations.where((d) => d.group == group),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _tiles(Iterable<MoreDestination> destinations) => [
  for (final (index, destination) in destinations.indexed) ...[
    if (index > 0) const Divider(indent: 72),
    _DestinationTile(destination: destination),
  ],
];

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination});

  final MoreDestination destination;

  @override
  Widget build(BuildContext context) {
    final brand = context.appColors.brand;
    return ListTile(
      key: Key('more_${destination.name}'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s4,
      ),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: brand.container,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(destination.icon, color: brand.onContainer, size: 22),
        ),
      ),
      title: Text(destination.title),
      subtitle: Text(destination.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.goNamed(destination.name),
    );
  }
}
