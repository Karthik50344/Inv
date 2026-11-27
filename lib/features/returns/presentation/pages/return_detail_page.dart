import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/return_numbering.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
          appBar: AppAppBar(title: doc?.number ?? ReturnNumbering.label(kind)),
          body: AppContentWidth(child: switch (state.status) {
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
          }),
        );
      },
    );
  }

  Widget _content(BuildContext context, ReturnDocument doc) {
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final isSales = doc.kind == InvoiceKind.sales;
    Widget totalRow(
      String label,
      String value, {
      Key? key,
      bool strong = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: strong
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
            ),
          ),
          AppSpacing.hGap12,
          Text(
            value,
            key: key,
            style: strong
                ? context.appText.financialMedium
                : context.appText.financialSmall,
          ),
        ],
      ),
    );
    return ListView(
      padding: AppSpacing.page,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppBadge(
            label: isSales ? 'Sales return' : 'Purchase return',
            tone: isSales ? AppTone.warning : AppTone.info,
            icon: Icons.assignment_return_outlined,
          ),
        ),
        AppSpacing.gap12,
        AppFactsCard(
          facts: [
            AppFact(isSales ? 'Customer' : 'Supplier', doc.partyName),
            AppFact(
              isSales ? 'Sales invoice' : 'Purchase invoice',
              doc.invoiceNumber,
              key: const Key('return_invoice'),
              onTap: () => context.pushNamed(
                isSales ? RouteNames.saleDetail : RouteNames.purchaseDetail,
                pathParameters: {'id': doc.invoiceId},
              ),
            ),
            AppFact('Date', formatDocumentDate(doc.returnDate)),
            AppFact('Reason', doc.reason, key: const Key('return_reason')),
          ],
        ),
        if (doc.notes != null) ...[
          AppSpacing.gap12,
          AppCard(
            child: Text(
              doc.notes!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
        const AppSectionHeader(
          title: 'Items',
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s24,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        ),
        for (final line in doc.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: AppCard(
              key: Key('return_line_${line.lineNo}'),
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${line.productName} (${line.sku})',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            '${line.quantity.toDecimalString()} '
                                '${line.unitSymbol}',
                            if (line.tax.isPositive)
                              'tax ${formatter.format(line.tax)}',
                            if (isSales)
                              line.restocked
                                  ? 'put back in stock'
                                  : 'not restocked'
                            else
                              'taken out of stock',
                            if (line.note != null) line.note!,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.hGap8,
                  AppCurrencyText(line.total),
                ],
              ),
            ),
          ),
        AppSpacing.gap8,
        AppCard(
          child: Column(
            children: [
              totalRow('Value without tax', formatter.format(doc.net)),
              totalRow('Tax', formatter.format(doc.tax)),
              AppSpacing.gap8,
              Divider(height: 1, color: tokens.divider),
              AppSpacing.gap8,
              totalRow(
                'Total returned',
                formatter.format(doc.total),
                key: const Key('return_total'),
                strong: true,
              ),
            ],
          ),
        ),
        if (doc.refund != null || doc.credit.isPositive) ...[
          AppSpacing.gap12,
          AppFactsCard(
            facts: [
              if (doc.refund != null)
                AppFact(
                  isSales ? 'Refunded in cash' : 'Refunded by supplier',
                  '${formatter.format(doc.refund!.amount)} · '
                      '${doc.refund!.methodName}',
                  key: const Key('return_refund'),
                ),
              if (doc.credit.isPositive)
                AppFact(
                  isSales
                      ? 'Kept as credit for the customer'
                      : 'Kept as credit with the supplier',
                  formatter.format(doc.credit),
                  key: const Key('return_credit'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
