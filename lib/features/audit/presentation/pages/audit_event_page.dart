import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_event_cubit.dart';
import 'package:inventrix/features/audit/presentation/support/audit_labels.dart';
import 'package:inventrix/features/audit/presentation/widgets/audit_event_tile.dart';
import 'package:inventrix/features/audit/presentation/widgets/value_diff.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// The full record of one audit event.
class AuditEventPage extends StatelessWidget {
  /// Creates the page for event [eventId].
  const AuditEventPage({required this.eventId, super.key});

  /// The event shown.
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Event details'),
      body: BlocBuilder<AuditEventCubit, AuditEventState>(
        builder: (context, state) {
          switch (state.status) {
            case ViewStatus.initial:
            case ViewStatus.loading:
              return const LoadingIndicator();
            case ViewStatus.failure:
            case ViewStatus.empty:
              return ErrorState(
                message: state.error ?? 'This audit event no longer exists.',
                onRetry: () => context.read<AuditEventCubit>().load(eventId),
              );
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

  final AuditEventState state;

  @override
  Widget build(BuildContext context) {
    final event = state.event!;
    final theme = Theme.of(context);
    final style = auditActionStyle(event.action);
    final summary = AuditLabels.summary(event);
    final details = {
      for (final e in (event.metadata ?? const <String, Object?>{}).entries)
        if (e.key != 'summary') e.key: e.value,
    };
    return AppContentWidth(
      child: ListView(
        padding: AppSpacing.page,
        children: [
          Row(
            children: [
              Expanded(child: Text(AuditLabels.title(event), style: theme.textTheme.headlineSmall)),
              AppBadge(label: AuditLabels.action(event.action), tone: style.tone, icon: style.icon),
            ],
          ),
          if (summary != null) ...[
            AppSpacing.gap8,
            Text(summary, style: theme.textTheme.bodyLarge),
          ],
          AppSpacing.gap16,
          AppFactsCard(
            facts: [
              AppFact('When', DateFormatter.dateTime(event.occurredAtUtc)),
              AppFact('Who', AuditLabels.actor(event.actor)),
              AppFact('Record', '${AuditLabels.entity(event.entityType)} · ${event.entityId}'),
              AppFact('Reason', event.reason ?? 'No reason was recorded'),
              AppFact('Where from', event.source == 'app' ? 'This app' : event.source),
            ],
          ),
          if (event.actor.type != AuditActorType.authenticatedUser) ...[
            AppSpacing.gap8,
            Text(
              'Inventrix has no sign-in yet, so the person shown is a name '
              'entered on this device. It is a label, not proof of identity.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const AppSectionHeader(title: 'What changed'),
          ValueDiff(previous: event.previousValues, next: event.newValues),
          if (details.isNotEmpty) ...[
            const AppSectionHeader(title: 'More details'),
            AppFactsCard(
              facts: [
                for (final e in details.entries)
                  AppFact(AuditLabels.field(e.key), AuditLabels.value(e.value)),
              ],
            ),
          ],
          const AppSectionHeader(title: 'Integrity'),
          _Integrity(event: event, valid: state.hashValid),
          if (state.related.isNotEmpty) ...[
            const AppSectionHeader(
              title: 'Done at the same time',
              subtitle: 'Other events recorded by the same action',
            ),
            for (final other in state.related)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: AuditEventTile(
                  event: other,
                  onTap: () => context.push(RoutePaths.auditEvent(other.id)),
                ),
              ),
          ],
          AppSpacing.gap24,
        ],
      ),
    );
  }
}

class _Integrity extends StatelessWidget {
  const _Integrity({required this.event, required this.valid});

  final AuditEvent event;
  final bool? valid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = valid ?? false;
    return AppCard(
      tone: ok ? AppTone.success : AppTone.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.verified_outlined : Icons.gpp_bad_outlined),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  ok
                      ? 'This event matches its recorded fingerprint.'
                      : 'This event does NOT match its recorded fingerprint. '
                            'It may have been changed after it was written.',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          AppSpacing.gap8,
          Text(
            'This checks this one event. To check that no event was removed '
            'or reordered, run "Check integrity" from the audit center.',
            style: theme.textTheme.bodySmall,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Technical details', style: theme.textTheme.labelLarge),
            children: [
              _Code(label: 'Event fingerprint', value: event.eventHash),
              _Code(label: 'Previous event fingerprint', value: event.previousEventHash),
              _Code(label: 'Event id', value: event.id),
              _Code(label: 'Operation id', value: event.correlationId),
              if (event.sequence != null) _Code(label: 'Position in the log', value: '${event.sequence}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                SelectableText(value, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                showAppMessage(context, 'Copied');
              }
            },
          ),
        ],
      ),
    );
  }
}
