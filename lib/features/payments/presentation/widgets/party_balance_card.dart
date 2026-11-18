import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_button.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Opening balance, invoices, payments and the amount outstanding for one
/// customer or supplier, with a button to record a payment.
///
/// Needs a [PartyBalanceCubit] above it in the tree (the router provides it
/// on the customer and supplier detail routes).
class PartyBalanceCard extends StatelessWidget {
  /// Creates the card.
  const PartyBalanceCard({
    required this.type,
    required this.partyId,
    super.key,
  });

  /// Customer or supplier.
  final PartyType type;

  /// The party's id.
  final String partyId;

  @override
  Widget build(BuildContext context) {
    return _Body(type: type, partyId: partyId);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.type, required this.partyId});

  final PartyType type;
  final String partyId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PartyBalanceCubit, PartyBalanceState>(
      builder: (context, state) {
        final balance = state.balance;
        if (state.status == ViewStatus.failure) {
          return AppCard(
            tone: AppTone.danger,
            child: Row(
              children: [
                Expanded(
                  child: Text(state.message ?? 'Could not load the balance.'),
                ),
                AppButton(
                  label: 'Retry',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.small,
                  onPressed: () =>
                      context.read<PartyBalanceCubit>().load(type, partyId),
                ),
              ],
            ),
          );
        }
        if (balance == null) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.s16),
            child: LinearProgressIndicator(),
          );
        }
        const formatter = MoneyFormatter();
        final isCustomer = type == PartyType.customer;
        final theme = Theme.of(context);
        final tokens = context.appColors;
        Widget row(String label, String value, {Key? key, bool bold = false}) =>
            Padding(
              key: key,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: bold
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: tokens.textSecondary,
                            ),
                    ),
                  ),
                  Text(
                    value,
                    style: bold
                        ? context.appText.financialMedium
                        : context.appText.financialSmall,
                  ),
                ],
              ),
            );
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row('Opening balance', formatter.format(balance.opening)),
              row(
                isCustomer ? 'Posted sales' : 'Posted purchases',
                formatter.format(balance.invoiced),
              ),
              if (balance.returns.isPositive)
                row(
                  isCustomer ? 'Returned by customer' : 'Returned to supplier',
                  formatter.format(balance.returns),
                  key: const Key('party_returns'),
                ),
              row(
                isCustomer ? 'Payments received' : 'Payments made',
                formatter.format(balance.payments),
              ),
              if (balance.refunds.isPositive || balance.returnRefunds.isPositive)
                row(
                  'Refunds',
                  formatter.format(balance.refunds + balance.returnRefunds),
                ),
              Divider(height: AppSpacing.s16, color: tokens.divider),
              row(
                balance.hasCredit
                    ? (isCustomer ? 'Advance from customer' : 'Advance to supplier')
                    : (isCustomer ? 'Outstanding receivable' : 'Outstanding payable'),
                formatter.format(balance.balance.abs()),
                key: const Key('party_balance'),
                bold: true,
              ),
              AppSpacing.gap12,
              AppButton(
                key: const Key('record_payment_for_party'),
                label: isCustomer ? 'Receive payment' : 'Pay supplier',
                icon: Icons.payments_outlined,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () async {
                  final cubit = context.read<PartyBalanceCubit>();
                  await context.pushNamed(
                    RouteNames.paymentNew,
                    queryParameters: {'type': type.dbName, 'party': partyId},
                  );
                  await cubit.load(type, partyId);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
