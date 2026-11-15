import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/return_numbering.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// A posted return: its lines, value, refund or credit, and a link to the
/// original invoice. Returns are final, so there are no edit actions.
class ReturnDetailPage extends StatelessWidget {
  /// Creates the page. Provide a [ReturnDetailCubit] above it.
  const ReturnDetailPage({
    required this.kind,
    required this.returnId,
    super.key,
  });

  /// Sales or purchase return.
  final InvoiceKind kind;

  /// The return id.
  final String returnId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReturnDetailCubit, ReturnDetailState>(
      builder: (context, state) {
        final doc = state.document;
        return Scaffold(
          appBar: AppBar(
            title: Text(doc?.number ?? ReturnNumbering.label(kind)),
          ),
          body: switch (state.status) {
            DetailStatus.loading => const LoadingIndicator(),
            DetailStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Return not found',
              message: 'It may have been removed or the link is wrong.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the return.',
              onRetry: () =>
                  context.read<ReturnDetailCubit>().load(kind, returnId),
            ),
            DetailStatus.loaded => _content(context, doc!),
          },
        );
      },
    );
  }

  Widget _content(BuildContext context, ReturnDocument doc) {
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final isSales = doc.kind == InvoiceKind.sales;
    Widget row(String label, String value, {Key? key, bool bold = false}) =>
        ListTile(
          key: key,
          dense: true,
          title: Text(label),
          trailing: Text(
            value,
            style: bold
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyMedium,
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        row(isSales ? 'Customer' : 'Supplier', doc.partyName),
        ListTile(
          key: const Key('return_invoice'),
          dense: true,
          title: Text(isSales ? 'Sales invoice' : 'Purchase invoice'),
          trailing: Text(doc.invoiceNumber),
          onTap: () => context.pushNamed(
            isSales ? RouteNames.saleDetail : RouteNames.purchaseDetail,
            pathParameters: {'id': doc.invoiceId},
          ),
        ),
        row('Date', formatDocumentDate(doc.returnDate)),
        row('Reason', doc.reason, key: const Key('return_reason')),
        if (doc.notes != null)
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            child: Text(doc.notes!),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm),
          child: Text('Items', style: theme.textTheme.titleMedium),
        ),
        for (final line in doc.lines)
          Card(
            key: Key('return_line_${line.lineNo}'),
            child: ListTile(
              title: Text('${line.productName} (${line.sku})'),
              subtitle: Text(
                [
                  '${line.quantity.toDecimalString()} ${line.unitSymbol}',
                  if (line.tax.isPositive) 'tax ${formatter.format(line.tax)}',
                  if (isSales)
                    line.restocked ? 'put back in stock' : 'not restocked'
                  else
                    'taken out of stock',
                  if (line.note != null) line.note!,
                ].join(' · '),
              ),
              trailing: Text(
                formatter.format(line.total),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
        const Divider(),
        row('Value without tax', formatter.format(doc.net)),
        row('Tax', formatter.format(doc.tax)),
        row(
          'Total returned',
          formatter.format(doc.total),
          key: const Key('return_total'),
          bold: true,
        ),
        if (doc.refund != null)
          row(
            isSales ? 'Refunded in cash' : 'Refunded by supplier',
            '${formatter.format(doc.refund!.amount)} · '
                '${doc.refund!.methodName}',
            key: const Key('return_refund'),
          ),
        if (doc.credit.isPositive)
          row(
            isSales
                ? 'Kept as credit for the customer'
                : 'Kept as credit with the supplier',
            formatter.format(doc.credit),
            key: const Key('return_credit'),
          ),
      ],
    );
  }
}
