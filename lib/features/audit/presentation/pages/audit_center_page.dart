import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_center_cubit.dart';
import 'package:inventrix/features/audit/presentation/support/audit_labels.dart';
import 'package:inventrix/features/audit/presentation/widgets/audit_event_tile.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_labels.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// The audit & export center: numbers from the real audit trail, recent
/// events and exports, and the way into every audit and export screen.
class AuditCenterPage extends StatelessWidget {
  /// Creates the page.
  const AuditCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Audit & export'),
      body: BlocBuilder<AuditCenterCubit, AuditCenterState>(
        builder: (context, state) {
          switch (state.status) {
            case ViewStatus.initial:
            case ViewStatus.loading:
              if (state.stats == null) {
                return const LoadingIndicator();
              }
              return _Content(state: state);
            case ViewStatus.failure:
              return ErrorState(
                message: state.error ?? 'Could not load the audit trail.',
                onRetry: () => context.read<AuditCenterCubit>().load(),
              );
            case ViewStatus.empty:
            case ViewStatus.loaded:
              return _Content(state: state);
          }
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final AuditCenterState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    if (stats == null) {
      return const LoadingIndicator();
    }
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => context.read<AuditCenterCubit>().load(),
      child: AppContentWidth(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Text(
              'Every important change is written to a tamper-evident log. '
              'Use it to answer who did what, and when, and to prepare data '
              'for your auditor.',
              style: theme.textTheme.bodyMedium,
            ),
            AppSpacing.gap16,
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 720 ? 3 : 2;
                final width = (box.maxWidth - AppSpacing.cardGap * (columns - 1)) / columns;
                Widget card(AppStatCard c) => SizedBox(width: width, child: c);
                return Wrap(
                  spacing: AppSpacing.cardGap,
                  runSpacing: AppSpacing.cardGap,
                  children: [
                    card(AppStatCard(label: 'Recorded events', value: '${stats.totalEvents}', icon: Icons.history, onTap: () => context.push(RoutePaths.auditLog))),
                    card(AppStatCard(label: 'Cancelled documents', value: '${stats.cancelledDocuments}', icon: Icons.block_outlined, tone: AppTone.danger)),
                    card(AppStatCard(label: 'Reversed payments', value: '${stats.reversedPayments}', icon: Icons.undo, tone: AppTone.warning)),
                    card(AppStatCard(label: 'Tax setting changes', value: '${stats.taxConfigurationChanges}', icon: Icons.percent, tone: AppTone.info)),
                    card(AppStatCard(label: 'Stock events', value: '${stats.stockAdjustments}', icon: Icons.inventory_2_outlined, tone: AppTone.neutral)),
                    card(AppStatCard(label: 'Exports created', value: '${stats.dataExports}', icon: Icons.ios_share, tone: AppTone.success, onTap: () => context.push(RoutePaths.auditExports))),
                  ],
                );
              },
            ),
            AppSpacing.gap16,
            Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s12,
              children: [
                AppButton(label: 'Create export', icon: Icons.ios_share, onPressed: () => context.push(RoutePaths.auditExport)),
                AppButton(label: 'Audit log', icon: Icons.list_alt_outlined, variant: AppButtonVariant.outlined, onPressed: () => context.push(RoutePaths.auditLog)),
                AppButton(label: 'Check integrity', icon: Icons.verified_outlined, variant: AppButtonVariant.outlined, onPressed: () => context.push(RoutePaths.auditIntegrity)),
              ],
            ),
            AppSpacing.gap16,
            _OperatorCard(name: state.operatorName),
            if (stats.byType.isNotEmpty) ...[
              const AppSectionHeader(title: 'What is recorded'),
              AppCard(
                child: Column(
                  children: [
                    for (final entry in stats.byType.entries.take(8))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                        child: Row(
                          children: [
                            Expanded(child: Text(_typeLabel(entry.key), style: theme.textTheme.bodyMedium)),
                            Text('${entry.value}', style: theme.textTheme.titleSmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            AppSectionHeader(
              title: 'Recent events',
              actionLabel: stats.recent.isEmpty ? null : 'See all',
              onAction: () => context.push(RoutePaths.auditLog),
            ),
            if (stats.recent.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: 'Nothing recorded yet',
                message: 'Events appear here as soon as you post, change or cancel something.',
              )
            else
              for (final event in stats.recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                  child: AuditEventTile(
                    event: event,
                    onTap: () => context.push(RoutePaths.auditEvent(event.id)),
                  ),
                ),
            AppSectionHeader(
              title: 'Recent exports',
              actionLabel: 'All exports',
              onAction: () => context.push(RoutePaths.auditExports),
            ),
            if (state.recentExports.isEmpty)
              Text('No export has been created yet.', style: theme.textTheme.bodyMedium)
            else
              for (final record in state.recentExports)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                  child: _ExportTile(record: record),
                ),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(String eventType) {
    final dot = eventType.indexOf('.');
    if (dot < 0) {
      return eventType;
    }
    return '${AuditLabels.entity(eventType.substring(0, dot))} ${eventType.substring(dot + 1).replaceAll('_', ' ')}';
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({required this.record});

  final ExportRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push(RoutePaths.auditExportDetail(record.id)),
      child: Row(
        children: [
          const Icon(Icons.folder_zip_outlined),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.name, style: theme.textTheme.titleSmall),
                AppSpacing.gap4,
                Text(
                  '${DateFormatter.dateTime(record.createdAt)}  ·  ${record.period.label}  ·  ${ExportLabels.size(record.sizeBytes)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ExportLabels.integrityBadge(record),
        ],
      ),
    );
  }
}

class _OperatorCard extends StatelessWidget {
  const _OperatorCard({required this.name});

  final String? name;

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<AuditCenterCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) => _OperatorDialog(initial: name ?? '', onSave: cubit.saveOperatorName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.person_outline),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Named on new events', style: theme.textTheme.labelLarge),
                AppSpacing.gap4,
                Text(name ?? 'This device (no name set)', style: theme.textTheme.titleSmall),
                AppSpacing.gap4,
                Text(
                  'A name you type for whoever uses this device. It is a '
                  'label, not proof of identity: Inventrix has no sign-in yet.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppButton(label: 'Change', variant: AppButtonVariant.text, onPressed: () => _edit(context)),
        ],
      ),
    );
  }
}

class _OperatorDialog extends StatefulWidget {
  const _OperatorDialog({required this.initial, required this.onSave});

  final String initial;
  final Future<Failure?> Function(String) onSave;

  @override
  State<_OperatorDialog> createState() => _OperatorDialogState();
}

class _OperatorDialogState extends State<_OperatorDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await widget.onSave(_controller.text);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = failure is ValidationFailure && failure.fieldErrors['name'] != null
          ? failure.fieldErrors['name']
          : failure.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Who uses this device?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(label: 'Name', hint: 'Leave empty to name the device', controller: _controller, errorText: _error),
          AppSpacing.gap8,
          Text('This name is written on every audit event made from now on.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
