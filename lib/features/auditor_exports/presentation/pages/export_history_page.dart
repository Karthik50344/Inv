import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_history_cubit.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_labels.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Past exports with their period, type, size and integrity state.
class ExportHistoryPage extends StatelessWidget {
  /// Creates the page.
  const ExportHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: 'Exports',
        actions: [
          AppIconButton(
            icon: Icons.add,
            tooltip: 'Create export',
            onPressed: () => context.push(RoutePaths.auditExport),
          ),
        ],
      ),
      body: BlocConsumer<ExportListCubit, ExportListState>(
        listenWhen: (a, b) => a.messageSerial != b.messageSerial && b.message != null,
        listener: (context, state) => showAppMessage(context, state.message!),
        builder: (context, state) {
          switch (state.status) {
            case ViewStatus.initial:
            case ViewStatus.loading:
              return const LoadingIndicator();
            case ViewStatus.failure:
              return ErrorState(
                message: state.error ?? 'Could not load the exports.',
                onRetry: () => context.read<ExportListCubit>().load(),
              );
            case ViewStatus.empty:
              return EmptyState(
                icon: Icons.ios_share,
                title: 'No exports yet',
                message: 'Create an export to give your auditor your records.',
                action: AppButton(
                  label: 'Create export',
                  icon: Icons.add,
                  onPressed: () => context.push(RoutePaths.auditExport),
                ),
              );
            case ViewStatus.loaded:
              final theme = Theme.of(context);
              return AppContentWidth(
                child: RefreshIndicator(
                  onRefresh: () => context.read<ExportListCubit>().load(),
                  child: ListView.separated(
                    padding: AppSpacing.page,
                    itemCount: state.records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
                    itemBuilder: (context, index) {
                      final r = state.records[index];
                      return AppCard(
                        onTap: () => context.push(RoutePaths.auditExportDetail(r.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(r.name, style: theme.textTheme.titleSmall)),
                                ExportLabels.integrityBadge(r),
                              ],
                            ),
                            AppSpacing.gap4,
                            Text(
                              '${DateFormatter.dateTime(r.createdAt)}  ·  ${r.period.label}',
                              style: theme.textTheme.bodySmall,
                            ),
                            AppSpacing.gap4,
                            Text(
                              '${r.format.label}  ·  ${ExportLabels.size(r.sizeBytes)}  ·  '
                              '${r.datasets.length} items',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}
