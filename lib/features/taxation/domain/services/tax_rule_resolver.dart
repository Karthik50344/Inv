import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/jurisdiction_rule_provider.dart';

/// A component together with the rule it came from.
final class ResolvedComponent {
  /// Creates the pair.
  const ResolvedComponent(this.rule, this.component);

  /// The rule.
  final TaxRule rule;

  /// The component.
  final TaxComponent component;
}

/// The rules and components that apply to one input.
final class ResolvedTax {
  /// Creates a resolution.
  const ResolvedTax({
    required this.profile,
    required this.category,
    required this.treatment,
    required this.relation,
    this.treatmentReason,
    this.rules = const [],
    this.components = const [],
  });

  /// The profile used.
  final TaxProfile profile;

  /// The category used.
  final TaxCategory category;

  /// The treatment that applies.
  final TaxTreatment treatment;

  /// Why the treatment differs from the category default.
  final String? treatmentReason;

  /// Derived seller / place-of-supply relation.
  final SupplyRelation relation;

  /// Rules that contribute components.
  final List<TaxRule> rules;

  /// Components in calculation order.
  final List<ResolvedComponent> components;
}

/// Picks the applicable tax rules for a transaction, deterministically.
///
/// Resolution order:
/// 1. Profile and category must exist and be active.
/// 2. The treatment is the input override, else the category default. Exempt,
///    zero-rated and out-of-scope treatments need no rule: tax is zero and
///    the treatment is recorded.
/// 3. Candidate rules: active, same profile and category, effective on the
///    transaction date, matching transaction type / customer status /
///    supply type / supply relation (a `null` selector matches anything),
///    and located at or above the place of supply (a `null` jurisdiction
///    means the whole regime).
/// 4. Of the non-stackable candidates the best by (priority, number of
///    selectors, jurisdiction depth) wins; a tie is a
///    [TaxRuleConflictFailure], never an arbitrary pick. Every stackable
///    candidate is applied in addition.
/// 5. No candidate at all is a [TaxConfigurationFailure], never 0% tax.
final class TaxRuleResolver {
  /// Creates a resolver. Country [providers] are consulted before
  /// [fallback].
  const TaxRuleResolver({
    this.providers = const [IndiaGstRuleProvider()],
    this.fallback = const DefaultJurisdictionRuleProvider(),
  });

  /// Country-specific providers.
  final List<JurisdictionRuleProvider> providers;

  /// Provider used when none supports the seller's country.
  final JurisdictionRuleProvider fallback;

  /// Resolves [input] against [configuration].
  Result<ResolvedTax> resolve(
    TaxConfiguration configuration,
    TaxCalculationInput input,
  ) {
    final profile = configuration.profile(input.taxProfileId);
    if (profile == null || !profile.isActive) {
      return const Result.failure(
        TaxConfigurationFailure('The tax profile is missing or inactive.'),
      );
    }
    final category = configuration.category(input.taxCategoryId);
    if (category == null || !category.isActive) {
      return const Result.failure(
        TaxConfigurationFailure(
          'The product tax category is missing or inactive.',
        ),
      );
    }

    final provider = _providerFor(input.sellerLocation.countryCode);
    final invalid = provider.validate(input);
    if (invalid != null) {
      return Result.failure(invalid);
    }
    final relation = provider.relationOf(input);

    var treatment = input.treatmentOverride ?? category.defaultTaxTreatment;
    String? reason;
    if (input.treatmentOverride != null) {
      reason = input.overrideReference == null
          ? 'Treatment overridden for this transaction.'
          : 'Treatment overridden: ${input.overrideReference}';
    }
    if (!provider.chargesTax(input)) {
      treatment = TaxTreatment.outOfScope;
      reason = 'The seller is not registered for this tax.';
    }
    if (!treatment.computesTax) {
      return Result.success(
        ResolvedTax(
          profile: profile,
          category: category,
          treatment: treatment,
          treatmentReason: reason,
          relation: relation,
        ),
      );
    }

    final place = configuration.resolveLocation(input.placeOfSupply);
    final ancestry = place == null
        ? const <String>[]
        : configuration.ancestry(place.id);

    final candidates = configuration.rules
        .where((r) => _applies(r, input, relation, ancestry, configuration))
        .toList();
    if (candidates.isEmpty) {
      return Result.failure(
        TaxConfigurationFailure(
          'No tax rule is set up for "${category.name}" in '
          '${input.placeOfSupply} on '
          '${_formatDate(input.transactionDate)}. '
          'Add a tax rule instead of assuming zero tax.',
        ),
      );
    }

    final stackable = candidates.where((r) => r.isStackable).toList();
    final competing = candidates.where((r) => !r.isStackable).toList();
    final chosen = <TaxRule>[];
    if (competing.isNotEmpty) {
      int depth(TaxRule r) => r.jurisdictionId == null
          ? 0
          : ancestry.length - ancestry.indexOf(r.jurisdictionId!);
      int compare(TaxRule a, TaxRule b) {
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) {
          return byPriority;
        }
        final bySelectors = b.selectorCount.compareTo(a.selectorCount);
        if (bySelectors != 0) {
          return bySelectors;
        }
        return depth(b).compareTo(depth(a));
      }

      competing.sort((a, b) {
        final byKey = compare(a, b);
        return byKey != 0 ? byKey : a.id.compareTo(b.id);
      });
      final ties = competing.where((r) => compare(competing.first, r) == 0);
      if (ties.length > 1) {
        return Result.failure(
          TaxRuleConflictFailure(
            'Several tax rules apply equally to "${category.name}" in '
            '${input.placeOfSupply}. Change their priority or dates so '
            'only one applies.',
            ruleIds: ties.map((r) => r.id).toList(),
          ),
        );
      }
      chosen.add(competing.first);
    }
    chosen.addAll(stackable..sort((a, b) => a.id.compareTo(b.id)));

    final components = <ResolvedComponent>[];
    final seen = <String, String>{};
    for (final rule in chosen) {
      for (final component in configuration.componentsOf(rule.id)) {
        final problem = _componentProblem(rule, component);
        if (problem != null) {
          return Result.failure(TaxConfigurationFailure(problem));
        }
        final key = '${component.componentType.code}|${component.name}';
        final owner = seen[key];
        if (owner != null && owner != rule.id) {
          return Result.failure(
            TaxRuleConflictFailure(
              '"${component.name}" would be applied by two rules at once.',
              ruleIds: [owner, rule.id],
            ),
          );
        }
        seen[key] = rule.id;
        components.add(ResolvedComponent(rule, component));
      }
    }
    components.sort((a, b) {
      final byOrder = a.component.calculationOrder.compareTo(
        b.component.calculationOrder,
      );
      if (byOrder != 0) {
        return byOrder;
      }
      return a.component.id.compareTo(b.component.id);
    });

    return Result.success(
      ResolvedTax(
        profile: profile,
        category: category,
        treatment: treatment,
        treatmentReason: reason,
        relation: relation,
        rules: chosen,
        components: components,
      ),
    );
  }

  JurisdictionRuleProvider _providerFor(String countryCode) {
    for (final provider in providers) {
      if (provider.supports(countryCode)) {
        return provider;
      }
    }
    return fallback;
  }

  bool _applies(
    TaxRule rule,
    TaxCalculationInput input,
    SupplyRelation relation,
    List<String> ancestry,
    TaxConfiguration configuration,
  ) {
    if (!rule.isActive ||
        rule.taxProfileId != input.taxProfileId ||
        rule.taxCategoryId != input.taxCategoryId ||
        !rule.isEffectiveOn(input.transactionDate)) {
      return false;
    }
    if (rule.transactionType != null &&
        rule.transactionType != input.transactionType) {
      return false;
    }
    if (rule.customerTaxStatus != null &&
        rule.customerTaxStatus != input.customerTaxStatus) {
      return false;
    }
    if (rule.supplyType != null && rule.supplyType != input.supplyType) {
      return false;
    }
    if (rule.supplyRelation != SupplyRelation.any &&
        rule.supplyRelation != relation) {
      return false;
    }
    final jurisdictionId = rule.jurisdictionId;
    if (jurisdictionId != null && !ancestry.contains(jurisdictionId)) {
      return false;
    }
    return configuration.componentsOf(rule.id).isNotEmpty;
  }

  String? _componentProblem(TaxRule rule, TaxComponent component) {
    switch (rule.calculationMethod) {
      case TaxCalculationMethod.percentage:
        if (component.rateBasisPoints < 0) {
          return '"${component.name}" has a negative rate.';
        }
      case TaxCalculationMethod.fixed:
        final fixed = component.fixedAmountMinor;
        if (fixed == null || fixed < 0) {
          return '"${component.name}" needs a fixed amount.';
        }
    }
    return null;
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
