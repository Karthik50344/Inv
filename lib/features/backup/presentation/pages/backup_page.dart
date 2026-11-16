import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/local_data_warning_banner.dart';

/// Backup, export and restore.
class BackupPage extends StatelessWidget {
  /// Creates the page.
  const BackupPage({super.key});

  Future<void> _pickFile(BuildContext context) async {
    final bloc = context.read<BackupBloc>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = result?.files.single.path;
    if (path != null) {
      bloc.add(BackupFileSelected(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
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
        appBar: AppBar(title: const Text('Backup & restore')),
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
                _Content(state: state, onPickFile: () => _pickFile(context)),
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
  const _Content({required this.state, required this.onPickFile});

  final BackupState state;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BackupBloc>();
    final last = state.lastBackupAt;
    return ListView(
      key: const Key('backup-history-list'),
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        const LocalDataWarningBanner(),
        const SizedBox(height: AppDimensions.spaceMd),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last backup', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  last == null
                      ? 'No backup has been made yet.'
                      : DateFormat.yMMMd().add_Hm().format(last.toLocal()),
                  key: const Key('backup-last'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                FilledButton.icon(
                  key: const Key('backup-create'),
                  onPressed: state.busy
                      ? null
                      : () => bloc.add(const BackupCreateRequested()),
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Create backup'),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                OutlinedButton.icon(
                  key: const Key('backup-restore-file'),
                  onPressed: state.busy ? null : onPickFile,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Restore from a file'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        Text('History', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppDimensions.spaceSm),
        if (state.status == ViewStatus.loading && state.records.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (state.records.isEmpty)
          const Text(
            'Backups you create appear here. Share or save them to a safe '
            'place outside this device.',
            key: Key('backup-empty'),
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
    final when = DateFormat.yMMMd().add_Hm().format(record.createdAt.toLocal());
    final details = [
      record.kind.label,
      when,
      if (record.kind != BackupKind.restore && !failed) _size(record.sizeBytes),
      if (record.exportedAt != null) 'exported',
      if (!record.hasStoredCopy && !failed && record.kind != BackupKind.restore)
        'copy deleted',
      if (failed) 'failed',
    ].join(' · ');
    return Card(
      child: ListTile(
        key: Key('backup-record-${record.id}'),
        leading: Icon(
          failed ? Icons.error_outline : Icons.inventory_2_outlined,
          color: failed ? theme.colorScheme.error : null,
        ),
        title: Text(record.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          failed && record.errorMessage != null
              ? '$details\n${record.errorMessage}'
              : details,
        ),
        isThreeLine: failed && record.errorMessage != null,
        trailing: record.hasStoredCopy
            ? PopupMenuButton<String>(
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
              )
            : null,
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
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppDimensions.spaceMd),
                  Text(_text, key: const Key('backup-busy-text')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
