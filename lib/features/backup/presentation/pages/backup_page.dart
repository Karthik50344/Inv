import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/backup/domain/services/backup_reminder.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/features/backup/presentation/widgets/backup_passphrase_dialogs.dart';
import 'package:inventrix/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
import 'package:inventrix/shared/presentation/widgets/local_data_warning_banner.dart';

/// Backup, export and restore.
class BackupPage extends StatelessWidget {
  /// Creates the page.
  const BackupPage({this.reminderDays = 0, super.key});

  /// Days between backup reminders from the settings (`0` = off).
  final int reminderDays;

  Future<void> _pickFile(BuildContext context) async {
    final bloc = context.read<BackupBloc>();
    final result = await FilePicker.pickFiles();
    final path = result.single.path;
    if (path != null) {
      bloc.add(BackupFileSelected(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        backupPassphraseListener(),
        BlocListener<BackupBloc, BackupState>(
          listenWhen: (a, b) =>
              (a.message != b.message && b.message != null) ||
              (a.error != b.error && b.error != null),
          listener: (context, state) =>
              showAppMessage(context, state.error ?? state.message!),
        ),
        BlocListener<BackupBloc, BackupState>(
          listenWhen: (a, b) =>
              a.preview == null &&
              b.preview != null &&
              b.activity == BackupActivity.idle,
          listener: (context, state) async {
            final bloc = context.read<BackupBloc>();
            final confirmed = await showRestoreConfirmationDialog(
              context,
              state.preview!,
            );
            bloc.add(
              confirmed
                  ? const BackupRestoreConfirmed()
                  : const BackupPreviewDiscarded(),
            );
          },
        ),
      ],
      child: Scaffold(
        appBar: const AppAppBar(title: 'Backup & restore'),
        body: BlocBuilder<BackupBloc, BackupState>(
          builder: (context, state) {
            if (state.status == ViewStatus.failure && state.records.isEmpty) {
              return ErrorState(
                message: state.error ?? 'Could not load the backup history.',
                onRetry: () =>
                    context.read<BackupBloc>().add(const BackupStarted()),
              );
            }
            return Stack(
              children: [
                AppContentWidth(
                  child: _Content(
                    state: state,
                    reminderDays: reminderDays,
                    onPickFile: () => _pickFile(context),
                  ),
                ),
                if (state.busy) _BusyOverlay(activity: state.activity),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.reminderDays,
    required this.onPickFile,
  });

  final BackupState state;
  final int reminderDays;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final bloc = context.read<BackupBloc>();
    final last = state.lastBackupAt;
    final brand = AppTone.brand.colors(context);
    return ListView(
      key: const Key('backup-history-list'),
      padding: AppSpacing.page,
      children: [
        const LocalDataWarningBanner(),
        AppSpacing.gap12,
        if (state.status == ViewStatus.loaded &&
            BackupReminder.isDue(
              reminderDays: reminderDays,
              lastExportedAt: state.lastExportedAt,
              now: DateTime.now(),
            )) ...[
          AppCard(
            key: const Key('backup-reminder'),
            tone: AppTone.warning,
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined),
                AppSpacing.hGap12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time to export a backup',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        state.lastExportedAt == null
                            ? 'No backup has been exported yet.'
                            : 'The last export was on '
                                  '${DateFormatter.dateTime(state.lastExportedAt!)}.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gap12,
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: brand.container,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.cloud_done_outlined,
                        size: 22,
                        color: brand.onContainer,
                      ),
                    ),
                  ),
                  AppSpacing.hGap12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last backup',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                        Text(
                          last == null
                              ? 'No backup has been made yet.'
                              : DateFormatter.dateTime(last),
                          key: const Key('backup-last'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.gap16,
              AppButton(
                key: const Key('backup-create'),
                label: 'Create backup',
                icon: Icons.backup_outlined,
                expand: true,
                onPressed: state.busy
                    ? null
                    : () async {
                        final passphrase = await showCreateBackupDialog(context);
                        if (passphrase != null) {
                          bloc.add(
                            BackupCreateRequested(
                              recoveryPassphrase:
                                  passphrase.isEmpty ? null : passphrase,
                            ),
                          );
                        }
                      },
              ),
              AppSpacing.gap8,
              AppButton(
                key: const Key('backup-restore-file'),
                label: 'Restore from a file',
                icon: Icons.restore_outlined,
                variant: AppButtonVariant.outlined,
                expand: true,
                onPressed: state.busy ? null : onPickFile,
              ),
            ],
          ),
        ),
        const AppSectionHeader(
          title: 'History',
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s24,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        ),
        if (state.status == ViewStatus.loading && state.records.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (state.records.isEmpty)
          Text(
            'Backups you create appear here. Share or save them to a safe '
            'place outside this device.',
            key: const Key('backup-empty'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          )
        else
          for (final record in state.records)
            _RecordTile(record: record, busy: state.busy),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.busy});

  final BackupRecord record;
  final bool busy;

  static String _size(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BackupBloc>();
    final failed = record.outcome == BackupOutcome.failed;
    final when = DateFormatter.dateTime(record.createdAt);
    final details = [
      record.kind.label,
      when,
      if (record.kind != BackupKind.restore && !failed) _size(record.sizeBytes),
      if (record.exportedAt != null) 'exported',
      if (!record.hasStoredCopy && !failed && record.kind != BackupKind.restore)
        'copy deleted',
      if (failed) 'failed',
    ].join(' · ');
    final tokens = context.appColors;
    final colors = (failed ? AppTone.danger : AppTone.neutral).colors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: AppCard(
        key: Key('backup-record-${record.id}'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s12,
          AppSpacing.s4,
          AppSpacing.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.container,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  failed ? Icons.error_outline : Icons.inventory_2_outlined,
                  size: 20,
                  color: colors.onContainer,
                ),
              ),
            ),
            AppSpacing.hGap12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    failed && record.errorMessage != null
                        ? '$details\n${record.errorMessage}'
                        : details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: failed ? colors.onContainer : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (record.hasStoredCopy)
              PopupMenuButton<String>(
                key: Key('backup-menu-${record.id}'),
                enabled: !busy,
                onSelected: (choice) async {
                  switch (choice) {
                    case 'share':
                      bloc.add(
                        BackupExportRequested(record.id, ExportMode.share),
                      );
                    case 'save':
                      bloc.add(
                        BackupExportRequested(
                          record.id,
                          ExportMode.saveToDevice,
                        ),
                      );
                    case 'restore':
                      bloc.add(BackupStoredSelected(record.id));
                    case 'delete':
                      final ok = await showConfirmationDialog(
                        context,
                        title: 'Delete stored copy?',
                        message:
                            'The backup file will be removed from this '
                            'device. Copies you exported are not affected.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                      if (ok) {
                        bloc.add(BackupDeleteRequested(record.id));
                      }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'share', child: Text('Share…')),
                  PopupMenuItem(value: 'save', child: Text('Save to device…')),
                  PopupMenuItem(value: 'restore', child: Text('Restore')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete stored copy'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.activity});

  final BackupActivity activity;

  String get _text => switch (activity) {
    BackupActivity.creating => 'Creating backup…',
    BackupActivity.exporting => 'Exporting…',
    BackupActivity.validating => 'Checking the backup…',
    BackupActivity.restoring => 'Restoring… do not close the app.',
    BackupActivity.idle => '',
  };

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.54),
        child: Center(
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                AppSpacing.gap16,
                Text(
                  _text,
                  key: const Key('backup-busy-text'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
