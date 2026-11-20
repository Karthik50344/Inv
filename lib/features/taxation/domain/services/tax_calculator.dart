import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_rule_resolver.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Calculates the tax of one line from the configuration. Pure and
/// deterministic: the same configuration and input always give the same
/// result, and every figure is exact integer arithmetic (BigInt
/// intermediates, half away from zero, never `double`).
///
/// Method:
/// - `after = gross - discount`.
/// - Components run in `calculationOrder`. A percentage component is
///   `rate x base`, where the base is the net amount, or for a compound
///   component the net amount plus the tax of the components before it. A
///   fixed component is `amount x quantity`.
/// - Tax-exclusive: `net = after`; each component is rounded once and the
///   tax total is their sum.
/// - Tax-inclusive: the net is derived exactly by inverting the whole
///   component chain, then components are computed forward from the net;
///   the last component absorbs any rounding remainder so that
///   `net + sum(components) = after` always holds.
/// - Reverse charge: the price contains no tax (`net = after`); the
///   components are reported as `reverseChargeTax` and nothing is added to
///   the total.
final class TaxCalculator {
  /// Creates a calculator.
  const TaxCalculator({this.resolver = const TaxRuleResolver()});

  /// Rule resolution.
  final TaxRuleResolver resolver;

  /// Taxes the line described by [input].
  Result<TaxCalculationResult> calculate(
    TaxConfiguration configuration,
    TaxCalculationInput input,
  ) {
    final gross = input.grossAmount;
    final currency = gross.currencyCode;
    final places = gross.decimalPlaces;
    Money money(int minor) => Money.fromMinor(
      minor,
      currencyCode: currency,
      decimalPlaces: places,
    );
    final discount = input.discount ?? money(0);

    if (gross.isNegative || discount.isNegative) {
      return const Result.failure(
        ValidationFailure('Amounts must not be negative.'),
      );
    }
    if (!input.quantity.isPositive) {
      return const Result.failure(
        ValidationFailure('The quantity must be more than zero.'),
      );
    }
    if (discount > gross) {
      return const Result.failure(
        ValidationFailure('The discount cannot be more than the line amount.'),
      );
    }
    final after = gross - discount;

    final resolution = resolver.resolve(configuration, input);
    final resolved = resolution.valueOrNull;
    if (resolved == null) {
      return Result.failure(resolution.failureOrNull!);
    }

    TaxCalculationResult build({
      required Money net,
      required List<TaxComponentResult> components,
      required Money charged,
      required Money reverseCharge,
    }) => TaxCalculationResult(
      taxProfileId: resolved.profile.id,
      regimeId: resolved.profile.regimeId,
      taxCategoryId: resolved.category.id,
      treatment: resolved.treatment,
      treatmentReason: resolved.treatmentReason,
      pricingMode: input.pricingMode,
      transactionDate: input.transactionDate,
      placeOfSupply: input.placeOfSupply,
      supplyRelation: resolved.relation,
      grossAmount: gross,
      discount: discount,
      taxableAmount: net,
      components: components,
      taxCharged: charged,
      reverseChargeTax: reverseCharge,
      totalAmount: net + charged,
      ruleIds: resolved.rules.map((r) => r.id).toList(),
      jurisdictionIds: [
        for (final r in resolved.rules)
          if (r.jurisdictionId != null) r.jurisdictionId!,
      ],
    );

    if (!resolved.treatment.computesTax) {
      return Result.success(
        build(
          net: after,
          components: const [],
          charged: money(0),
          reverseCharge: money(0),
        ),
      );
    }

    final steps = resolved.components;
    final unitFixed = <int>[
      for (final s in steps)
        s.rule.calculationMethod == TaxCalculationMethod.fixed
            ? money(s.component.fixedAmountMinor!)
                  .multiplyByQuantity(input.quantity)
                  .minorUnits
            : 0,
    ];

    final inclusive =
        input.pricingMode == PricingMode.inclusive &&
        resolved.treatment != TaxTreatment.reverseCharge;

    BigInt net;
    if (inclusive) {
      final derived = _netFromInclusive(
        total: after.minorUnits,
        steps: steps,
        fixed: unitFixed,
      );
      if (derived == null) {
        return const Result.failure(
          ValidationFailure(
            'The tax is more than the price. Check the amount and the tax '
            'rules.',
          ),
        );
      }
      net = derived;
    } else {
      net = BigInt.from(after.minorUnits);
    }
    if (!net.isValidInt) {
      return const Result.failure(
        ValidationFailure('The amount is too large to calculate.'),
      );
    }
    final netMinor = net.toInt();

    final amounts = <int>[];
    final bases = <int>[];
    var taxSoFar = 0;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      int amount;
      int base;
      if (step.rule.calculationMethod == TaxCalculationMethod.fixed) {
        amount = unitFixed[i];
        base = netMinor;
      } else {
        base = step.component.isCompound ? netMinor + taxSoFar : netMinor;
        amount = _roundDiv(
          BigInt.from(base) * BigInt.from(step.component.rateBasisPoints),
          BigInt.from(10000),
        ).toInt();
      }
      amounts.add(amount);
      bases.add(base);
      taxSoFar += amount;
    }
    if (inclusive) {
      final remainder = (after.minorUnits - netMinor) - taxSoFar;
      final last = amounts.length - 1;
      if (amounts[last] + remainder < 0) {
        return const Result.failure(
          ValidationFailure('The tax could not be split across components.'),
        );
      }
      amounts[last] += remainder;
      taxSoFar += remainder;
    }

    final components = <TaxComponentResult>[
      for (var i = 0; i < steps.length; i++)
        TaxComponentResult(
          ruleId: steps[i].rule.id,
          componentId: steps[i].component.id,
          name: steps[i].component.name,
          type: steps[i].component.componentType,
          method: steps[i].rule.calculationMethod,
          rateBasisPoints:
              steps[i].rule.calculationMethod == TaxCalculationMethod.percentage
              ? steps[i].component.rateBasisPoints
              : null,
          fixedAmount:
              steps[i].rule.calculationMethod == TaxCalculationMethod.fixed
              ? money(steps[i].component.fixedAmountMinor!)
              : null,
          taxableAmount: money(bases[i]),
          amount: money(amounts[i]),
          calculationOrder: steps[i].component.calculationOrder,
          isCompound: steps[i].component.isCompound,
          isRecoverable: steps[i].component.isRecoverable,
        ),
    ];
    final total = money(taxSoFar);
    final isReverse = resolved.treatment == TaxTreatment.reverseCharge;
    return Result.success(
      build(
        net: money(netMinor),
        components: components,
        charged: isReverse ? money(0) : total,
        reverseCharge: isReverse ? total : money(0),
      ),
    );
  }

  /// Inverts `total = net + sum(components(net))`, which is affine in the
  /// net: `total = net x (1 + a) + b`. `a` and `b` are kept as exact
  /// fractions over `den`. Returns `null` when the fixed taxes exceed the
  /// total.
  BigInt? _netFromInclusive({
    required int total,
    required List<ResolvedComponent> steps,
    required List<int> fixed,
  }) {
    final ten000 = BigInt.from(10000);
    var den = BigInt.one;
    var a = BigInt.zero;
    var b = BigInt.zero;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.rule.calculationMethod == TaxCalculationMethod.fixed) {
        b += BigInt.from(fixed[i]) * den;
        continue;
      }
      final rate = BigInt.from(step.component.rateBasisPoints);
      if (step.component.isCompound) {
        a = a * ten000 + rate * (den + a);
        b = b * ten000 + rate * b;
      } else {
        a = a * ten000 + rate * den;
        b = b * ten000;
      }
      den = den * ten000;
    }
    final numerator = BigInt.from(total) * den - b;
    if (numerator.isNegative) {
      return null;
    }
    return _roundDiv(numerator, den + a);
  }

  /// `n / d` rounded half up for `n >= 0`, `d > 0`.
  BigInt _roundDiv(BigInt n, BigInt d) =>
      (n * BigInt.two + d) ~/ (d * BigInt.two);
}
