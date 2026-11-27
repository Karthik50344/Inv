import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/audit/domain/entities/audit_query.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_log_cubit.dart';
import 'package:inventrix/features/audit/presentation/support/audit_labels.dart';
import 'package:inventrix/features/audit/presentation/widgets/audit_event_tile.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_preset.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Search, filter and read the audit events.
class AuditLogPage extends StatefulWidget {
  /// Creates the page.
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        context.read<AuditLogCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openFilters(BuildContext context) async {
    final cubit = context.read<AuditLogCubit>();
    final result = await showModalBottomSheet<AuditEventFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        initial: cubit.state.filter,
        eventTypes: cubit.state.eventTypes,
        entityTypes: cubit.state.entityTypes,
      ),
    );
    if (result != null) {
      await cubit.apply(result);
    }
  }

  void _export(BuildContext context, AuditLogState state) {
    final f = state.filter;
    context.push(
      RoutePaths.auditExport,
      extra: ExportPreset.auditTrail(from: f.from, to: f.to),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: 'Audit log',
        actions: [
          BlocBuilder<AuditLogCubit, AuditLogState>(
            builder: (context, state) => AppIconButton(
              icon: Icons.ios_share,
              tooltip: 'Export the audit trail',
              onPressed: () => _export(context, state),
            ),
          ),
        ],
      ),
      body: BlocBuilder<AuditLogCubit, AuditLogState>(
        builder: (context, state) {
          return AppContentWidth(
            child: Column(
              children: [
                AppSearchField(
                  hintText: 'Search events, document numbers, people',
                  onChanged: context.read<AuditLogCubit>().search,
                  trailing: AppFilterButton(
                    activeCount: state.activeFilterCount,
                    onPressed: () => _openFilters(context),
                  ),
                ),
                if (state.activeFilterCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: 'Clear filters',
                        variant: AppButtonVariant.text,
                        icon: Icons.close,
                        onPressed: context.read<AuditLogCubit>().clearFilters,
                      ),
                    ),
                  ),
                Expanded(child: _body(context, state)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, AuditLogState state) {
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.error ?? 'Could not load the audit log.',
          onRetry: () => context.read<AuditLogCubit>().apply(state.filter),
        );
      case ViewStatus.empty:
        return EmptyState(
          icon: Icons.search_off,
          title: 'No events found',
          message: state.activeFilterCount > 0 || state.filter.search.isNotEmpty
              ? 'Try a different search or clear the filters.'
              : 'Events appear here as you post, change or cancel things.',
        );
      case ViewStatus.loaded:
        return ListView.separated(
          controller: _scroll,
          padding: AppSpacing.page,
          itemCount: state.events.length + (state.loadingMore || state.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (context, index) {
            if (index >= state.events.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.s16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final event = state.events[index];
            return AuditEventTile(
              event: event,
              onTap: () => context.push(RoutePaths.auditEvent(event.id)),
            );
          },
        );
    }
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.eventTypes,
    required this.entityTypes,
  });

  final AuditEventFilter initial;
  final List<String> eventTypes;
  final List<String> entityTypes;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  late String? _eventType = widget.initial.eventType;
  late String? _entityType = widget.initial.entityType;
  late final TextEditingController _actor = TextEditingController(text: widget.initial.actor);
  late final TextEditingController _reference = TextEditingController(text: widget.initial.reference);

  @override
  void dispose() {
    _actor.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final range = await showAppDateRangePicker(
      context,
      initial: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter the log', style: theme.textTheme.titleMedium),
            AppSpacing.gap16,
            AppButton(
              label: _from == null
                  ? 'Any date'
                  : '${DateFormatter.date(_from!)} to ${DateFormatter.date(_to!)}',
              icon: Icons.date_range_outlined,
              variant: AppButtonVariant.outlined,
              expand: true,
              onPressed: _pickRange,
            ),
            if (_from != null)
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Any date',
                  variant: AppButtonVariant.text,
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                  }),
                ),
              ),
            AppSpacing.gap12,
            AppDropdown<String?>(
              label: 'What happened',
              value: _eventType,
              items: [
                const AppDropdownItem<String?>(value: null, label: 'Anything'),
                for (final t in widget.eventTypes)
                  AppDropdownItem<String?>(value: t, label: _label(t)),
              ],
              onChanged: (v) => setState(() => _eventType = v),
            ),
            AppSpacing.gap12,
            AppDropdown<String?>(
              label: 'Kind of record',
              value: _entityType,
              items: [
                const AppDropdownItem<String?>(value: null, label: 'Any record'),
                for (final t in widget.entityTypes)
                  AppDropdownItem<String?>(value: t, label: AuditLabels.entity(t)),
              ],
              onChanged: (v) => setState(() => _entityType = v),
            ),
            AppSpacing.gap12,
            AppTextField(label: 'Document number', hint: 'For example INV-0012', controller: _reference),
            AppSpacing.gap12,
            AppTextField(label: 'Person', hint: 'Name of the operator', controller: _actor),
            AppSpacing.gap16,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Clear',
                    variant: AppButtonVariant.outlined,
                    onPressed: () => Navigator.of(context).pop(
                      AuditEventFilter(search: widget.initial.search, limit: widget.initial.limit),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: AppButton(
                    label: 'Apply',
                    onPressed: () => Navigator.of(context).pop(
                      AuditEventFilter(
                        search: widget.initial.search,
                        from: _from,
                        to: _to,
                        eventType: _eventType,
                        entityType: _entityType,
                        actor: _actor.text,
                        reference: _reference.text,
                        limit: widget.initial.limit,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String type) {
    final dot = type.indexOf('.');
    return dot < 0
        ? type
        : '${AuditLabels.entity(type.substring(0, dot))} ${type.substring(dot + 1).replaceAll('_', ' ')}';
  }
}
