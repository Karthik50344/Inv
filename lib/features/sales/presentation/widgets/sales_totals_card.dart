import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';

/// Subtotal, discount, tax and total of an invoice.
class SalesTotalsCard extends StatelessWidget {
  /// Creates the card.
  const SalesTotalsCard({required this.totals, super.key});

  /// Totals to show.
  final SalesTotals totals;

  @override
  Widget build(BuildContext context) {
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final tokens = context.appColors;
    Widget row(String label, String value, {bool strong = false, Key? key}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: strong
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
              ),
              Text(
                value,
                key: key,
                style: strong
                    ? context.appText.financialMedium
                    : context.appText.financialSmall,
              ),
            ],
          ),
        );
    return AppCard(
      child: Column(
        children: [
          row('Subtotal', formatter.format(totals.gross)),
          if (totals.discount.isPositive)
            row('Discount', '- ${formatter.format(totals.discount)}'),
          row('Tax', formatter.format(totals.tax)),
          AppSpacing.gap8,
          Divider(height: 1, color: tokens.divider),
          AppSpacing.gap8,
          row(
            'Total',
            formatter.format(totals.total),
            strong: true,
            key: const Key('sales_total'),
          ),
        ],
      ),
    );
  }
}
