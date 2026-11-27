import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_wizard_cubit.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_labels.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Four steps to an auditor export: period, content, file type, review.
class ExportWizardPage extends StatelessWidget {
  /// Creates the page.
  const ExportWizardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExportWizardCubit, ExportWizardState>(
      builder: (context, state) {
        final done = state.record != null;
        return PopScope(
          canPop: !state.submitting,
          child: Scaffold(
            appBar: AppAppBar(title: done ? 'Export ready' : 'Create export'),
            body: AppContentWidth(
              child: done
                  ? _Done(state: state)
                  : Column(
                      children: [
                        _Progress(step: state.step),
                        Expanded(child: _stepBody(context, state)),
                        _Buttons(state: state),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _stepBody(BuildContext context, ExportWizardState state) {
    switch (state.step) {
      case ExportStep.period:
        return _PeriodStep(state: state);
      case ExportStep.content:
        return _ContentStep(state: state);
      case ExportStep.format:
        return _FormatStep(state: state);
      case ExportStep.review:
        return _ReviewStep(state: state);
    }
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final ExportStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s12, AppSpacing.s16, AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${step.index + 1} of ${ExportStep.values.length}: ${step.label}',
            style: theme.textTheme.titleSmall,
          ),
          AppSpacing.gap8,
          LinearProgressIndicator(value: (step.index + 1) / ExportStep.values.length),
        ],
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.state});

  final ExportWizardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExportWizardCubit>();
    final last = state.step == ExportStep.review;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            if (state.step != ExportStep.period) ...[
              Expanded(
                child: AppButton(
                  label: 'Back',
                  variant: AppButtonVariant.outlined,
                  onPressed: state.submitting ? null : cubit.back,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
            ],
            Expanded(
              flex: 2,
              child: AppButton(
                label: last ? 'Create export' : 'Next',
                icon: last ? Icons.ios_share : Icons.arrow_forward,
                loading: state.submitting,
                onPressed: state.submitting ? null : (last ? cubit.submit : cubit.next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodStep extends StatelessWidget {
  const _PeriodStep({required this.state});

  final ExportWizardState state;

  Future<void> _pickRange(BuildContext context) async {
    final cubit = context.read<ExportWizardCubit>();
    final range = await showAppDateRangePicker(
      context,
      initial: state.customFrom != null && state.customTo != null
          ? DateTimeRange(start: state.customFrom!, end: state.customTo!)
          : null,
    );
    if (range != null) {
      cubit.setCustomRange(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExportWizardCubit>();
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.page,
      children: [
        Text('Which period should the export cover?', style: theme.textTheme.titleMedium),
        AppSpacing.gap12,
        SegmentedButton<ExportPeriodKind>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ExportPeriodKind.financialYear, label: Text('Financial year')),
            ButtonSegment(value: ExportPeriodKind.custom, label: Text('Dates')),
            ButtonSegment(value: ExportPeriodKind.all, label: Text('Everything')),
          ],
          selected: {state.periodKind},
          onSelectionChanged: (s) => cubit.setPeriodKind(s.first),
        ),
        AppSpacing.gap16,
        if (state.periodKind == ExportPeriodKind.financialYear) ...[
          AppDropdown<int>(
            label: 'Year starts in',
            value: state.fyStartMonth,
            items: const [
              AppDropdownItem(value: 4, label: 'April (April to March)'),
              AppDropdownItem(value: 1, label: 'January (calendar year)'),
            ],
            onChanged: (v) => cubit.setFyStartMonth(v ?? 4),
          ),
          AppSpacing.gap12,
          AppDropdown<int>(
            label: 'Year',
            value: state.fyStartYear,
            items: [
              for (final year in cubit.fyYears)
                AppDropdownItem(
                  value: year,
                  label: ExportPeriod.financialYear(year, startMonth: state.fyStartMonth).label,
                ),
            ],
            onChanged: (v) => cubit.setFyStartYear(v ?? state.fyStartYear),
          ),
        ],
        if (state.periodKind == ExportPeriodKind.custom) ...[
          AppButton(
            label: state.customFrom == null || state.customTo == null
                ? 'Choose the first and last day'
                : '${DateFormatter.date(state.customFrom!)} to ${DateFormatter.date(state.customTo!)}',
            icon: Icons.date_range_outlined,
            variant: AppButtonVariant.outlined,
            expand: true,
            onPressed: () => _pickRange(context),
          ),
        ],
        if (state.periodKind == ExportPeriodKind.all)
          Text('Every record is included, whatever its date.', style: theme.textTheme.bodyMedium),
        if (state.periodError != null) ...[
          AppSpacing.gap8,
          Text(state.periodError!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
        ],
        AppSpacing.gap16,
        Text(
          'Documents (invoices, payments, expenses) are chosen by their own '
          'date. Your product, customer and supplier lists, tax settings and '
          'stock levels are always exported as they are today.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ContentStep extends StatelessWidget {
  const _ContentStep({required this.state});

  final ExportWizardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExportWizardCubit>();
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.page,
      children: [
        Row(
          children: [
            Expanded(child: Text('What should be included?', style: theme.textTheme.titleMedium)),
            AppButton(label: 'All', variant: AppButtonVariant.text, onPressed: cubit.selectAll),
            AppButton(label: 'None', variant: AppButtonVariant.text, onPressed: cubit.selectNone),
          ],
        ),
        if (state.contentError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Text(state.contentError!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ),
        for (final dataset in ExportDataset.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: state.datasets.contains(dataset),
            onChanged: (v) => cubit.toggleDataset(dataset, selected: v ?? false),
            title: Text(dataset.label),
            subtitle: Text(
              '${ExportLabels.datasetHelp(dataset)}'
              '${dataset.usesPeriod ? '' : ' (as of today)'}',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
      ],
    );
  }
}

class _FormatStep extends StatelessWidget {
  const _FormatStep({required this.state});

  final ExportWizardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExportWizardCubit>();
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.page,
      children: [
        Text('Which file type?', style: theme.textTheme.titleMedium),
        AppSpacing.gap12,
        for (final format in ExportFormat.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
            child: AppCard(
              selected: state.format == format,
              onTap: () => cubit.setFormat(format),
              child: Row(
                children: [
                  Icon(
                    state.format == format ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(format.label, style: theme.textTheme.titleSmall),
                        AppSpacing.gap4,
                        Text(ExportLabels.formatHelp(format), style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});

  final ExportWizardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExportWizardCubit>();
    final theme = Theme.of(context);
    final period = state.period;
    final chosen = ExportDataset.values.where(state.datasets.contains).toList();
    return ListView(
      padding: AppSpacing.page,
      children: [
        Text('Check and create', style: theme.textTheme.titleMedium),
        AppSpacing.gap12,
        AppFactsCard(
          facts: [
            AppFact('Period', period?.label ?? 'Not chosen'),
            AppFact('File type', state.format.label),
            AppFact('Included', '${chosen.length} items: ${chosen.map((d) => d.label).join(', ')}'),
          ],
        ),
        AppSpacing.gap12,
        AppTextField(
          label: 'Name (optional)',
          hint: 'For example Year-end audit',
          initialValue: state.name,
          onChanged: cubit.setName,
        ),
        AppSpacing.gap16,
        Text(
          'Your data is only read, never changed. The file is checked after '
          'it is saved and stays on this device until you choose to share it; '
          'nothing is uploaded. The package is not digitally signed: its '
          'checksums show it was not altered after export, but not who made it.',
          style: theme.textTheme.bodySmall,
        ),
        if (state.error != null) ...[
          AppSpacing.gap12,
          AppCard(
            tone: AppTone.danger,
            child: Text(state.error!, style: theme.textTheme.bodyMedium),
          ),
        ],
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.state});

  final ExportWizardState state;

  @override
  Widget build(BuildContext context) {
    final record = state.record!;
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.page,
      children: [
        const Icon(Icons.verified_outlined, size: 48),
        AppSpacing.gap12,
        Text('Your export is ready', style: theme.textTheme.headlineSmall),
        AppSpacing.gap8,
        Text(
          'It was saved on this device and checked after saving. Open it to '
          'share it with your auditor or save a copy.',
          style: theme.textTheme.bodyMedium,
        ),
        AppSpacing.gap16,
        AppFactsCard(
          facts: [
            AppFact('Name', record.name),
            AppFact('Period', record.period.label),
            AppFact('Size', ExportLabels.size(record.sizeBytes)),
            AppFact('Audit log', ExportLabels.chain(record.chainStatus)),
          ],
        ),
        AppSpacing.gap16,
        AppButton(
          label: 'Share or save',
          icon: Icons.ios_share,
          expand: true,
          onPressed: () => context.pushReplacement(RoutePaths.auditExportDetail(record.id)),
        ),
        AppSpacing.gap8,
        AppButton(
          label: 'Done',
          variant: AppButtonVariant.outlined,
          expand: true,
          onPressed: () => context.go(RoutePaths.audit),
        ),
      ],
    );
  }
}
