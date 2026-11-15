import 'package:flutter/material.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';

/// Small badge showing low or out-of-stock; nothing for healthy stock.
class StockStatusChip extends StatelessWidget {
  /// Creates the chip.
  const StockStatusChip({required this.status, super.key});

  /// Status to show.
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case StockStatus.ok:
        return const SizedBox.shrink();
      case StockStatus.low:
        return Chip(
          key: const Key('status_low'),
          label: const Text('Low'),
          backgroundColor: scheme.tertiaryContainer,
          visualDensity: VisualDensity.compact,
        );
      case StockStatus.out:
        return Chip(
          key: const Key('status_out'),
          label: const Text('Out of stock'),
          backgroundColor: scheme.errorContainer,
          visualDensity: VisualDensity.compact,
        );
    }
  }
}
