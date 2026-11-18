import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Size of an [AppCurrencyText].
enum AppCurrencySize {
  /// Headline amount (KPI, invoice total).
  large,

  /// Amount in a card or summary row.
  medium,

  /// Amount in a list row or table cell.
  small,
}

/// Shows a [Money] amount with tabular figures, in the user's currency and
/// number style (never a hardcoded symbol).
class AppCurrencyText extends StatelessWidget {
  /// Creates the text.
  const AppCurrencyText(
    this.money, {
    this.size = AppCurrencySize.small,
    this.tone,
    this.colorizeNegative = false,
    this.showSymbol = true,
    this.textAlign,
    super.key,
  });

  /// The amount.
  final Money money;

  /// Type size.
  final AppCurrencySize size;

  /// Optional color meaning (for example success for "paid").
  final AppTone? tone;

  /// Shows negative amounts in the danger color.
  final bool colorizeNegative;

  /// Includes the currency symbol.
  final bool showSymbol;

  /// Alignment inside its box.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final styles = context.appText;
    final base = switch (size) {
      AppCurrencySize.large => styles.financialLarge,
      AppCurrencySize.medium => styles.financialMedium,
      AppCurrencySize.small => styles.financialSmall,
    };
    final effective = colorizeNegative && money.minorUnits < 0
        ? AppTone.danger
        : tone;
    return Text(
      const MoneyFormatter().format(money, withSymbol: showSymbol),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: effective == null
          ? base
          : base.copyWith(color: effective.textColor(context)),
    );
  }
}
