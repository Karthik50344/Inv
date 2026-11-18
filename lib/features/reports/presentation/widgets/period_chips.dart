import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/presentation/widgets/app_chip.dart';
import 'package:inventrix/shared/presentation/widgets/app_date_picker.dart';

/// A row of period choices with a custom-range picker.
class PeriodChips extends StatelessWidget {
  /// Creates the chips. [onChanged] gets the period and, for
  /// [ReportPeriod.custom], the range the user picked.
  const PeriodChips({
    required this.selected,
    required this.current,
    required this.onChanged,
    this.periods = ReportPeriod.values,
    super.key,
  });

  /// The selected period.
  final ReportPeriod selected;

  /// The range currently shown (start value of the custom picker).
  final DateRange? current;

  /// Called when a period (or custom range) is chosen.
  final void Function(ReportPeriod period, DateRange? range) onChanged;

  /// Periods to offer.
  final List<ReportPeriod> periods;

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final range = current;
    final picked = await showAppDateRangePicker(
      context,
      first: DateTime(2000),
      last: DateTime(now.year + 1, 12, 31),
      initial: range == null
          ? null
          : DateTimeRange(start: range.from, end: range.to),
    );
    if (picked != null) {
      onChanged(
        ReportPeriod.custom,
        DateRange(from: picked.start, to: picked.end),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        children: [
          for (final period in periods)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: AppChip(
                key: Key('period_${period.name}'),
                label: period.label,
                icon: period == ReportPeriod.custom
                    ? Icons.date_range_outlined
                    : null,
                selected: selected == period,
                onSelected: (_) => period == ReportPeriod.custom
                    ? _pickRange(context)
                    : onChanged(period, null),
              ),
            ),
        ],
      ),
    );
  }
}
