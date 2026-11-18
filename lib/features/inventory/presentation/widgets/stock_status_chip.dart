import 'package:flutter/material.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_badge.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Small badge showing low or out-of-stock; nothing for healthy stock.
class StockStatusChip extends StatelessWidget {
  /// Creates the chip.
  const StockStatusChip({required this.status, super.key});

  /// Status to show.
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StockStatus.ok:
        return const SizedBox.shrink();
      case StockStatus.low:
        return const AppBadge(
          key: Key('status_low'),
          label: 'Low',
          tone: AppTone.warning,
        );
      case StockStatus.out:
        return const AppBadge(
          key: Key('status_out'),
          label: 'Out of stock',
          tone: AppTone.danger,
        );
    }
  }
}
