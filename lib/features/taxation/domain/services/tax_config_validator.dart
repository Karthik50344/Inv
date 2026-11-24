import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';

/// Checks tax configuration before it is saved. Every method returns a map
/// of field name to message; an empty map means valid. Rules are checked
/// against the rest of the configuration so a mistake is caught while the
/// user is editing, not when an invoice is being made.
abstract final class TaxConfigValidator {
  static final RegExp _country = RegExp(r'^[A-Z]{2}$');
  static final RegExp _currency = RegExp(r'^[A-Z]{3}$');
  static final RegExp _region = RegExp(r'^[A-Za-z0-9\-]{1,10}$');
  static final RegExp _typeCode = RegExp(r'^[a-z0-9_]{1,30}$');

  /// Checks a regime.
  static Map<String, String> regime(TaxRegime r) {
    final e = <String, String>{};
    _name(r.name, e);
    if (!_country.hasMatch(r.countryCode)) {
      e['countryCode'] = 'Use a 2-letter country code in capitals, for example IN.';
    }
    if (!_currency.hasMatch(r.currencyCode)) {
      e['currencyCode'] = 'Use a 3-letter currency code in capitals, for example INR.';
    }
    return e;
  }

  /// Checks a jurisdiction.
  static Map<String, String> jurisdiction(TaxJurisdiction j, TaxConfiguration c) {
    final e = <String, String>{};
    if (c.regime(j.regimeId) == null) {
      e['regimeId'] = 'Choose a tax system.';
    }
    if (!_country.hasMatch(j.countryCode)) {
      e['countryCode'] = 'Use a 2-letter country code in capitals, for example IN.';
    }
    final region = j.regionCode;
    if (region != null && !_region.hasMatch(region)) {
      e['regionCode'] = 'Use up to 10 letters, numbers or dashes.';
    }
    if (!_typeCode.hasMatch(j.jurisdictionType.code)) {
      e['jurisdictionType'] = 'Choose the kind of place.';
    }
    final parent = j.parentJurisdictionId;
    if (parent != null) {
      if (c.jurisdiction(parent) == null) {
        e['parentJurisdictionId'] = 'The containing place no longer exists.';
      } else if (parent == j.id || c.ancestry(parent).contains(j.id)) {
        e['parentJurisdictionId'] = 'A place cannot be inside itself.';
      }
    }
    return e;
  }

  /// Checks a category (its code must be unique).
  static Map<String, String> category(TaxCategory cat, TaxConfiguration c) {
    final e = <String, String>{};
    _name(cat.name, e);
    final code = cat.code.trim();
    if (code.isEmpty || code.length > 20) {
      e['code'] = 'Enter a short code (up to 20 characters).';
    } else if (c.categories.any(
      (o) => o.id != cat.id && o.code.toLowerCase() == code.toLowerCase(),
    )) {
      e['code'] = 'Another category already uses this code.';
    }
    return e;
  }

  /// Checks a profile.
  static Map<String, String> profile(TaxProfile p, TaxConfiguration c) {
    final e = <String, String>{};
    _name(p.name, e);
    if (c.regime(p.regimeId) == null) {
      e['regimeId'] = 'Choose a tax system.';
    }
    final category = p.defaultTaxCategoryId;
    if (category != null) {
      final found = c.category(category);
      if (found == null || !found.isActive) {
        e['defaultTaxCategoryId'] = 'Choose an active category.';
      }
    }
    if (p.isDefault && !p.isActive) {
      e['isActive'] = 'The default profile must stay on.';
    }
    return e;
  }

  /// Checks an override.
  static Map<String, String> override(TaxOverride o, TaxConfiguration c) {
    final e = <String, String>{};
    _name(o.name, e);
    final category = c.category(o.taxCategoryId);
    if (category == null || !category.isActive) {
      e['taxCategoryId'] = 'Choose an active category.';
    }
    if (o.reason.trim().length < 3) {
      e['reason'] = 'Say why this product is treated differently.';
    }
    return e;
  }

  /// Checks a rule, including whether it would tie with another rule.
  static Map<String, String> rule(TaxRule r, TaxConfiguration c) {
    final e = <String, String>{};
    if (c.profile(r.taxProfileId) == null) {
      e['taxProfileId'] = 'Choose a tax profile.';
    }
    final category = c.category(r.taxCategoryId);
    if (category == null) {
      e['taxCategoryId'] = 'Choose a tax category.';
    } else if (!category.defaultTaxTreatment.computesTax) {
      e['taxCategoryId'] =
          '"${category.name}" is ${category.defaultTaxTreatment.label.toLowerCase()}, '
          'so it never charges tax and needs no rule.';
    }
    final jurisdiction = r.jurisdictionId;
    if (jurisdiction != null && c.jurisdiction(jurisdiction) == null) {
      e['jurisdictionId'] = 'The place no longer exists.';
    }
    if (r.effectiveUntil != null && r.effectiveUntil!.isBefore(r.effectiveFrom)) {
      e['effectiveUntil'] = 'The end date must not be before the start date.';
    }
    if (r.priority < -1000 || r.priority > 1000) {
      e['priority'] = 'Use a number between -1000 and 1000.';
    }
    final status = r.customerTaxStatus;
    if (status != null && status.length > 30) {
      e['customerTaxStatus'] = 'Use at most 30 characters.';
    }
    final supply = r.supplyType;
    if (supply != null && supply.length > 30) {
      e['supplyType'] = 'Use at most 30 characters.';
    }
    if (e.isEmpty && r.isActive && !r.isStackable) {
      final tie = ruleTie(r, c);
      if (tie != null) {
        e['priority'] =
            'Another rule (${_describe(tie)}) applies in exactly the same '
            'situation with the same priority. Change the priority or the '
            'dates so only one applies.';
      }
    }
    return e;
  }

  /// The active, non-stackable rule that is identical to [r] in everything
  /// that decides which rule wins and that overlaps it in time, or `null`.
  /// Rules that differ in their selectors can still tie for some
  /// transactions; those are reported when a calculation runs.
  static TaxRule? ruleTie(TaxRule r, TaxConfiguration c) {
    for (final other in c.rules) {
      if (other.id == r.id ||
          !other.isActive ||
          other.isStackable ||
          other.taxProfileId != r.taxProfileId ||
          other.taxCategoryId != r.taxCategoryId ||
          other.jurisdictionId != r.jurisdictionId ||
          other.transactionType != r.transactionType ||
          other.customerTaxStatus != r.customerTaxStatus ||
          other.supplyType != r.supplyType ||
          other.supplyRelation != r.supplyRelation ||
          other.priority != r.priority) {
        continue;
      }
      if (_overlap(r, other)) {
        return other;
      }
    }
    return null;
  }

  static bool _overlap(TaxRule a, TaxRule b) {
    final aEnd = a.effectiveUntil;
    final bEnd = b.effectiveUntil;
    final aStartsBeforeBEnds = bEnd == null || !a.effectiveFrom.isAfter(bEnd);
    final bStartsBeforeAEnds = aEnd == null || !b.effectiveFrom.isAfter(aEnd);
    return aStartsBeforeBEnds && bStartsBeforeAEnds;
  }

  static String _describe(TaxRule r) =>
      'from ${_date(r.effectiveFrom)}'
      '${r.effectiveUntil == null ? '' : ' to ${_date(r.effectiveUntil!)}'}';

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Checks a component against its rule and the rule's other components.
  static Map<String, String> component(TaxComponent comp, TaxConfiguration c) {
    final e = <String, String>{};
    final rule = c.rules.where((r) => r.id == comp.taxRuleId).firstOrNull;
    if (rule == null) {
      e['taxRuleId'] = 'The rule no longer exists.';
    }
    _name(comp.name, e);
    if (!_typeCode.hasMatch(comp.componentType.code)) {
      e['componentType'] = 'Use lower-case letters, numbers and underscores.';
    }
    if (comp.calculationOrder < 1 || comp.calculationOrder > 99) {
      e['calculationOrder'] = 'Use a number from 1 to 99.';
    }
    if (rule != null) {
      switch (rule.calculationMethod) {
        case TaxCalculationMethod.percentage:
          if (comp.rateBasisPoints < 0 || comp.rateBasisPoints > 100000) {
            e['rateBasisPoints'] = 'The rate must be between 0% and 1000%.';
          }
        case TaxCalculationMethod.fixed:
          if (comp.fixedAmountMinor == null || comp.fixedAmountMinor! < 0) {
            e['fixedAmountMinor'] = 'Enter the amount charged per unit.';
          }
          if (comp.isCompound) {
            e['isCompound'] = 'A fixed amount cannot be compounded.';
          }
      }
    }
    final clash = c.components.any(
      (o) =>
          o.id != comp.id &&
          o.taxRuleId == comp.taxRuleId &&
          o.isActive &&
          comp.isActive &&
          o.name.toLowerCase() == comp.name.trim().toLowerCase() &&
          o.componentType == comp.componentType,
    );
    if (clash) {
      e['name'] = 'This rule already has a component with this name and type.';
    }
    return e;
  }

  /// Why [kind] record [id] cannot be switched off, or `null`.
  static String? cannotDeactivate(TaxConfiguration c, String kindCode, String id) {
    if (kindCode == 'tax_profile') {
      final p = c.profile(id);
      if (p != null && p.isDefault) {
        return 'This is the default profile. Make another profile the default first.';
      }
    }
    if (kindCode == 'tax_category') {
      final using = c.profiles.where((p) => p.defaultTaxCategoryId == id && p.isActive);
      if (using.isNotEmpty) {
        return 'It is the default category of "${using.first.name}". Change that first.';
      }
    }
    return null;
  }

  static void _name(String name, Map<String, String> e) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      e['name'] = 'Enter a name.';
    } else if (trimmed.length > 60) {
      e['name'] = 'Use at most 60 characters.';
    }
  }
}
