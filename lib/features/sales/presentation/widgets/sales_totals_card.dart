import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';

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
    Widget row(String label, String value, {bool strong = false, Key? key}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: strong
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium,
              ),
              Text(
                value,
                key: key,
                style: strong
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          children: [
            row('Subtotal', formatter.format(totals.gross)),
            if (totals.discount.isPositive)
              row('Discount', '- ${formatter.format(totals.discount)}'),
            row('Tax', formatter.format(totals.tax)),
            const Divider(),
            row(
              'Total',
              formatter.format(totals.total),
              strong: true,
              key: const Key('sales_total'),
            ),
          ],
        ),
      ),
    );
  }
}
