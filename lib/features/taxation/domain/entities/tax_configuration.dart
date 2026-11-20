import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';

/// An immutable, in-memory copy of the whole tax configuration.
///
/// The engine reads only this object, so calculations are deterministic and
/// need no database. Build it with `TaxRepository.loadConfiguration`.
final class TaxConfiguration {
  /// Creates a configuration; lookups are indexed once.
  TaxConfiguration({
    this.regimes = const [],
    this.jurisdictions = const [],
    this.categories = const [],
    this.profiles = const [],
    this.overrides = const [],
    this.rules = const [],
    this.components = const [],
  }) : _jurisdictionsById = {for (final j in jurisdictions) j.id: j},
       _categoriesById = {for (final c in categories) c.id: c},
       _profilesById = {for (final p in profiles) p.id: p},
       _overridesById = {for (final o in overrides) o.id: o},
       _regimesById = {for (final r in regimes) r.id: r};

  /// All regimes.
  final List<TaxRegime> regimes;

  /// All jurisdictions.
  final List<TaxJurisdiction> jurisdictions;

  /// All categories.
  final List<TaxCategory> categories;

  /// All profiles.
  final List<TaxProfile> profiles;

  /// All overrides.
  final List<TaxOverride> overrides;

  /// All rules.
  final List<TaxRule> rules;

  /// All components.
  final List<TaxComponent> components;

  final Map<String, TaxJurisdiction> _jurisdictionsById;
  final Map<String, TaxCategory> _categoriesById;
  final Map<String, TaxProfile> _profilesById;
  final Map<String, TaxOverride> _overridesById;
  final Map<String, TaxRegime> _regimesById;

  /// The regime with [id], if any.
  TaxRegime? regime(String id) => _regimesById[id];

  /// The category with [id], if any.
  TaxCategory? category(String id) => _categoriesById[id];

  /// The profile with [id], if any.
  TaxProfile? profile(String id) => _profilesById[id];

  /// The override with [id], if any.
  TaxOverride? override(String id) => _overridesById[id];

  /// The jurisdiction with [id], if any.
  TaxJurisdiction? jurisdiction(String id) => _jurisdictionsById[id];

  /// The profile marked as default and active, if any.
  TaxProfile? get defaultProfile {
    for (final profile in profiles) {
      if (profile.isDefault && profile.isActive) {
        return profile;
      }
    }
    return null;
  }

  /// Active components of [ruleId], in calculation order.
  List<TaxComponent> componentsOf(String ruleId) {
    final list = components
        .where((c) => c.taxRuleId == ruleId && c.isActive)
        .toList();
    list.sort((a, b) {
      final byOrder = a.calculationOrder.compareTo(b.calculationOrder);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
    return list;
  }

  /// The jurisdiction matching [location]: its explicit id, otherwise the
  /// active jurisdiction with the same country and region code (a
  /// country-level one when no region is given).
  TaxJurisdiction? resolveLocation(TaxLocation location) {
    final id = location.jurisdictionId;
    if (id != null) {
      return _jurisdictionsById[id];
    }
    for (final j in jurisdictions) {
      if (!j.isActive || j.countryCode != location.countryCode) {
        continue;
      }
      if (j.regionCode == location.regionCode) {
        return j;
      }
    }
    return null;
  }

  /// [jurisdictionId] followed by its parents up to the root. Cycles are
  /// cut, so a corrupt parent chain cannot loop forever.
  List<String> ancestry(String jurisdictionId) {
    final chain = <String>[];
    String? current = jurisdictionId;
    while (current != null && !chain.contains(current)) {
      final node = _jurisdictionsById[current];
      if (node == null) {
        break;
      }
      chain.add(current);
      current = node.parentJurisdictionId;
    }
    return chain;
  }
}
