import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/services/report_filter_options.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_bloc.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_event.dart';
import 'package:inventrix/features/reports/presentation/widgets/period_chips.dart';
import 'package:inventrix/features/reports/presentation/widgets/report_formatters.dart';
import 'package:inventrix/features/reports/presentation/widgets/report_view.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// One report with its period and filters. Provide a [ReportBloc] above it
/// (already started with the report's kind).
class ReportPage extends StatelessWidget {
  /// Creates the page.
  const ReportPage({required this.kind, super.key});

  /// The report shown.
  final ReportKind kind;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportBloc, ReportState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.message != previous.message &&
          current.status != ViewStatus.failure,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<ReportBloc>();
        final filter = state.filter;
        final canExport =
            state.document != null &&
            state.exportStatus != SubmitStatus.submitting;
        return Scaffold(
          appBar: AppBar(
            title: Text(kind.title),
            actions: [
              IconButton(
                key: const Key('report_export'),
                tooltip: 'Export CSV',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: canExport
                    ? () => bloc.add(const ReportExportRequested())
                    : null,
              ),
            ],
          ),
          body: Column(
            children: [
              if (kind.usesDateRange && filter != null) ...[
                PeriodChips(
                  selected: state.period,
                  current: filter.range,
                  onChanged: (period, range) =>
                      bloc.add(ReportPeriodChanged(period, range: range)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceMd,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ReportFormatters.range(
                        filter.range.from,
                        filter.range.to,
                      ),
                      key: const Key('report_range'),
                    ),
                  ),
                ),
              ],
              if (filter != null) _Filters(kind: kind, state: state),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ReportState state) {
    final bloc = context.read<ReportBloc>();
    final document = state.document;
    switch (state.status) {
      case ViewStatus.initial:
        return const LoadingIndicator();
      case ViewStatus.loading:
        return document == null
            ? const LoadingIndicator()
            : Stack(
                children: [
                  ReportView(document: document),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(),
                  ),
                ],
              );
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not build the report.',
          onRetry: () => bloc.add(const ReportRefreshed()),
        );
      case ViewStatus.empty:
        return ReportView(
          document: document!,
          emptyMessage: kind.usesDateRange
              ? 'Nothing recorded in this period.'
              : 'Nothing to show.',
        );
      case ViewStatus.loaded:
        return RefreshIndicator(
          onRefresh: () async => bloc.add(const ReportRefreshed()),
          child: ReportView(document: document!),
        );
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.kind, required this.state});

  final ReportKind kind;
  final ReportState state;

  @override
  Widget build(BuildContext context) {
    final filter = state.filter!;
    final bloc = context.read<ReportBloc>();
    Widget picker({
      required Key key,
      required String all,
      required String? value,
      required List<ReportOption> options,
      required ReportFilter Function(String? id) apply,
    }) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMd,
        vertical: 2,
      ),
      child: DropdownButton<String?>(
        key: key,
        isExpanded: true,
        value: options.any((o) => o.id == value) ? value : null,
        hint: Text(all),
        items: [
          DropdownMenuItem<String?>(child: Text(all)),
          for (final o in options)
            DropdownMenuItem<String?>(
              value: o.id,
              child: Text(o.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) => bloc.add(ReportFilterChanged(apply(id))),
      ),
    );

    return Column(
      children: [
        if (kind.supportsProduct)
          picker(
            key: const Key('filter_product'),
            all: 'All products',
            value: filter.productId,
            options: state.choices.products,
            apply: (id) => id == null
                ? filter.copyWith(clearProduct: true)
                : filter.copyWith(productId: id),
          ),
        if (kind.supportsCustomer)
          picker(
            key: const Key('filter_customer'),
            all: 'All customers',
            value: filter.customerId,
            options: state.choices.customers,
            apply: (id) => id == null
                ? filter.copyWith(clearCustomer: true)
                : filter.copyWith(customerId: id),
          ),
        if (kind.supportsSupplier)
          picker(
            key: const Key('filter_supplier'),
            all: 'All suppliers',
            value: filter.supplierId,
            options: state.choices.suppliers,
            apply: (id) => id == null
                ? filter.copyWith(clearSupplier: true)
                : filter.copyWith(supplierId: id),
          ),
      ],
    );
  }
}
