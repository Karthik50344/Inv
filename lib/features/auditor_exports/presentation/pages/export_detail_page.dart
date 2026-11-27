import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_history_cubit.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_labels.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// One export: its facts, integrity, and the actions on its file.
class ExportDetailPage extends StatelessWidget {
  /// Creates the page.
  const ExportDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Export details'),
      body: BlocConsumer<ExportListCubit, ExportListState>(
        listenWhen: (a, b) => a.messageSerial != b.messageSerial && b.message != null,
        listener: (context, state) => showAppMessage(context, state.message!),
        builder: (context, state) {
          switch (state.status) {
            case ViewStatus.initial:
            case ViewStatus.loading:
              return const LoadingIndicator();
            case ViewStatus.failure:
            case ViewStatus.empty:
              return ErrorState(
                message: state.error ?? 'This export no longer exists.',
                onRetry: () => context.read<ExportListCubit>().load(),
              );
            case ViewStatus.loaded:
              return _Content(record: state.records.single, busy: state.busyId != null);
          }
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.record, required this.busy});

  final ExportRecord record;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExportListCubit>();
    final theme = Theme.of(context);
    return AppContentWidth(
      child: ListView(
        padding: AppSpacing.page,
        children: [
          Row(
            children: [
              Expanded(child: Text(record.name, style: theme.textTheme.headlineSmall)),
              ExportLabels.integrityBadge(record),
            ],
          ),
          AppSpacing.gap16,
          AppFactsCard(
            facts: [
              AppFact('Created', DateFormatter.dateTime(record.createdAt)),
              AppFact('Period', record.period.label),
              AppFact('File type', record.format.label),
              AppFact('Size', ExportLabels.size(record.sizeBytes)),
              AppFact('Audit log at the time', ExportLabels.chain(record.chainStatus)),
              AppFact('Checked', record.verifiedAt == null ? 'Never' : DateFormatter.dateTime(record.verifiedAt!)),
              AppFact('App version', record.appVersion),
            ],
          ),
          const AppSectionHeader(title: 'What is inside'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final d in record.datasets) Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                child: Text('• ${d.label}', style: theme.textTheme.bodyMedium),
              )],
            ),
          ),
          const AppSectionHeader(title: 'File fingerprint'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(record.sha256, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                AppSpacing.gap8,
                Text(
                  'Anyone can recompute this code from the file to confirm '
                  'it was not changed. It does not show who created it.',
                  style: theme.textTheme.bodySmall,
                ),
                AppButton(
                  label: 'Copy',
                  icon: Icons.copy,
                  variant: AppButtonVariant.text,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: record.sha256));
                    if (context.mounted) {
                      showAppMessage(context, 'Copied');
                    }
                  },
                ),
              ],
            ),
          ),
          AppSpacing.gap16,
          if (record.hasFile) ...[
            AppButton(
              label: 'Share',
              icon: Icons.ios_share,
              expand: true,
              loading: busy,
              onPressed: busy ? null : () => cubit.share(record.id, ExportMode.share),
            ),
            AppSpacing.gap8,
            AppButton(
              label: 'Save to device',
              icon: Icons.download_outlined,
              variant: AppButtonVariant.outlined,
              expand: true,
              onPressed: busy ? null : () => cubit.share(record.id, ExportMode.saveToDevice),
            ),
            AppSpacing.gap8,
            AppButton(
              label: 'Check the file again',
              icon: Icons.verified_outlined,
              variant: AppButtonVariant.outlined,
              expand: true,
              onPressed: busy ? null : () => cubit.verify(record.id),
            ),
            AppSpacing.gap8,
            AppButton(
              label: 'Remove the file from this device',
              icon: Icons.delete_outline,
              variant: AppButtonVariant.destructive,
              expand: true,
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await showConfirmationDialog(
                        context,
                        title: 'Remove the file?',
                        message: 'The file is deleted from this device. This '
                            'entry and its record in the audit log stay. Make '
                            'sure you have shared or saved a copy first.',
                        confirmLabel: 'Remove file',
                        destructive: true,
                      );
                      if (ok && context.mounted) {
                        await cubit.deleteFile(record.id);
                      }
                    },
            ),
          ] else
            Text(
              'The file was removed from this device. This record stays as '
              'part of your history.',
              style: theme.textTheme.bodyMedium,
            ),
          AppSpacing.gap24,
        ],
      ),
    );
  }
}
