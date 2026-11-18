import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';

/// One label/value line of an [AppFactsCard].
class AppFact {
  /// Creates a fact. A null [value] is shown as an em dash.
  const AppFact(this.label, this.value, {this.key, this.onTap});

  /// Left-hand label.
  final String label;

  /// Right-hand value.
  final String? value;

  /// Key set on the value text, for tests.
  final Key? key;

  /// Makes the whole line tappable and shows a chevron.
  final VoidCallback? onTap;
}

/// A card of label/value lines separated by dividers. Used on detail pages
/// instead of ad hoc `ListTile` rows.
class AppFactsCard extends StatelessWidget {
  /// Creates the card.
  const AppFactsCard({required this.facts, super.key});

  /// Lines to show, in order.
  final List<AppFact> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s4,
      ),
      child: Column(
        children: [
          for (var i = 0; i < facts.length; i++)
            InkWell(
              onTap: facts[i].onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                decoration: BoxDecoration(
                  border: i == facts.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: tokens.divider)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facts[i].label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                    AppSpacing.hGap16,
                    Expanded(
                      child: Text(
                        facts[i].value ?? '—',
                        key: facts[i].key,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (facts[i].onTap != null) ...[
                      AppSpacing.hGap4,
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: tokens.textSecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
