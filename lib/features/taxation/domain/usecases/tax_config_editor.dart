import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_config_repository.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';
import 'package:inventrix/features/taxation/domain/services/tax_config_validator.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Creates and edits tax configuration.
///
/// Every save is checked first (`TaxConfigValidator`), then the change and
/// its audit event (with before and after values) are committed in one
/// transaction. Records are never deleted, only switched off, so every rule
/// that ever applied stays traceable. A save that changes nothing records
/// nothing. Posted documents are never affected: they keep their own tax
/// snapshot.
final class TaxConfigEditor {
  /// Creates the editor.
  const TaxConfigEditor({
    required TaxRepository read,
    required TaxConfigRepository write,
    required TaxPreferencesRepository preferences,
    required TransactionRunner transactions,
    required AuditLogRepository audit,
    required Clock clock,
    required IdGenerator ids,
  }) : _read = read,
       _write = write,
       _preferences = preferences,
       _transactions = transactions,
       _audit = audit,
       _clock = clock,
       _ids = ids;

  final TaxRepository _read;
  final TaxConfigRepository _write;
  final TaxPreferencesRepository _preferences;
  final TransactionRunner _transactions;
  final AuditLogRepository _audit;
  final Clock _clock;
  final IdGenerator _ids;

  /// Creates or edits a regime. Returns its id.
  Future<Result<String>> saveRegime(TaxRegime r) => _save<TaxRegime>(
    kind: TaxConfigKind.regime,
    item: r,
    id: r.id,
    name: r.name,
    validate: (x, c) => TaxConfigValidator.regime(x),
    find: (c, id) => c.regime(id),
    values: (x) => {
      'name': x.name.trim(),
      'countryCode': x.countryCode,
      'currencyCode': x.currencyCode,
      'description': x.description,
      'isActive': x.isActive,
    },
    write: _write.saveRegime,
  );

  /// Creates or edits a jurisdiction. Returns its id.
  Future<Result<String>> saveJurisdiction(TaxJurisdiction j) =>
      _save<TaxJurisdiction>(
        kind: TaxConfigKind.jurisdiction,
        item: j,
        id: j.id,
        name: j.regionName ?? j.regionCode ?? j.countryCode,
        validate: TaxConfigValidator.jurisdiction,
        find: (c, id) => c.jurisdiction(id),
        values: (x) => {
          'regimeId': x.regimeId,
          'countryCode': x.countryCode,
          'regionCode': x.regionCode,
          'regionName': x.regionName,
          'type': x.jurisdictionType.code,
          'parentJurisdictionId': x.parentJurisdictionId,
          'isActive': x.isActive,
        },
        write: _write.saveJurisdiction,
      );

  /// Creates or edits a category. Returns its id.
  Future<Result<String>> saveCategory(TaxCategory cat) => _save<TaxCategory>(
    kind: TaxConfigKind.category,
    item: cat,
    id: cat.id,
    name: cat.name,
    validate: TaxConfigValidator.category,
    find: (c, id) => c.category(id),
    values: (x) => {
      'name': x.name.trim(),
      'code': x.code.trim(),
      'description': x.description,
      'treatment': x.defaultTaxTreatment.code,
      'isActive': x.isActive,
    },
    write: _write.saveCategory,
  );

  /// Creates or edits a profile. Returns its id.
  Future<Result<String>> saveProfile(TaxProfile p) => _save<TaxProfile>(
    kind: TaxConfigKind.profile,
    item: p,
    id: p.id,
    name: p.name,
    validate: TaxConfigValidator.profile,
    find: (c, id) => c.profile(id),
    values: (x) => {
      'name': x.name.trim(),
      'regimeId': x.regimeId,
      'description': x.description,
      'isDefault': x.isDefault,
      'defaultTaxCategoryId': x.defaultTaxCategoryId,
      'isActive': x.isActive,
    },
    write: _write.saveProfile,
  );

  /// Creates or edits a product tax override. Returns its id.
  Future<Result<String>> saveOverride(TaxOverride o) => _save<TaxOverride>(
    kind: TaxConfigKind.override,
    item: o,
    id: o.id,
    name: o.name,
    validate: TaxConfigValidator.override,
    find: (c, id) => c.override(id),
    values: (x) => {
      'name': x.name.trim(),
      'taxCategoryId': x.taxCategoryId,
      'reason': x.reason.trim(),
      'isActive': x.isActive,
    },
    write: _write.saveOverride,
  );

  /// Creates or edits a rule. Returns its id.
  Future<Result<String>> saveRule(TaxRule r) => _save<TaxRule>(
    kind: TaxConfigKind.rule,
    item: r,
    id: r.id,
    name: 'rule ${r.id}',
    validate: TaxConfigValidator.rule,
    find: (c, id) => c.rules.where((x) => x.id == id).firstOrNull,
    values: (x) => {
      'taxProfileId': x.taxProfileId,
      'taxCategoryId': x.taxCategoryId,
      'jurisdictionId': x.jurisdictionId,
      'transactionType': x.transactionType?.code,
      'customerTaxStatus': x.customerTaxStatus,
      'supplyType': x.supplyType,
      'supplyRelation': x.supplyRelation.code,
      'calculationMethod': x.calculationMethod.code,
      'isStackable': x.isStackable,
      'effectiveFrom': _date(x.effectiveFrom),
      'effectiveUntil': x.effectiveUntil == null ? null : _date(x.effectiveUntil!),
      'priority': x.priority,
      'isActive': x.isActive,
    },
    write: _write.saveRule,
  );

  /// Creates or edits a component. Returns its id.
  Future<Result<String>> saveComponent(TaxComponent comp) => _save<TaxComponent>(
    kind: TaxConfigKind.component,
    item: comp,
    id: comp.id,
    name: comp.name,
    validate: TaxConfigValidator.component,
    find: (c, id) => c.components.where((x) => x.id == id).firstOrNull,
    values: (x) => {
      'taxRuleId': x.taxRuleId,
      'name': x.name.trim(),
      'type': x.componentType.code,
      'rateBasisPoints': x.rateBasisPoints,
      'fixedAmountMinor': x.fixedAmountMinor,
      'calculationOrder': x.calculationOrder,
      'isCompound': x.isCompound,
      'isRecoverable': x.isRecoverable,
      'isActive': x.isActive,
    },
    write: _write.saveComponent,
  );

  /// A new id for a record about to be created.
  String newId() => _ids.newId();

  /// Switches a record on or off.
  Future<Result<void>> setActive(
    TaxConfigKind kind,
    String id, {
    required bool active,
  }) async {
    final loaded = await _read.loadConfiguration();
    final config = loaded.valueOrNull;
    if (config == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (!active) {
      final blocked = TaxConfigValidator.cannotDeactivate(config, kind.entityType, id);
      if (blocked != null) {
        return Result.failure(ValidationFailure(blocked));
      }
    }
    final now = _clock.now();
    return _transactions.runResult<void>(() async {
      (await _write.setActive(kind, id, active: active, now: now)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: kind.entityType,
          entityId: id,
          action: active ? 'activated' : 'deactivated',
          summary: '${kind.entityType.replaceAll('_', ' ')} '
              '${active ? 'switched on' : 'switched off'}.',
          occurredAt: now,
          previousValues: {'isActive': !active},
          newValues: {'isActive': active},
        ),
      )).getOrThrow();
    });
  }

  /// Saves the business-level tax preferences.
  Future<Result<void>> savePreferences(TaxPreferences next) async {
    final errors = <String, String>{};
    final country = next.countryCode;
    if (country != null && !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      errors['countryCode'] = 'Use a 2-letter country code in capitals, for example IN.';
    }
    final region = next.regionCode;
    if (region != null && !RegExp(r'^[A-Za-z0-9\-]{1,10}$').hasMatch(region)) {
      errors['regionCode'] = 'Use up to 10 letters, numbers or dashes.';
    }
    if (errors.isNotEmpty) {
      return Result.failure(
        ValidationFailure('Please correct the highlighted fields.', fieldErrors: errors),
      );
    }
    final loaded = await _preferences.load();
    final before = loaded.valueOrNull;
    if (before == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    Map<String, Object?> values(TaxPreferences p) => {
      'countryCode': p.countryCode,
      'regionCode': p.regionCode,
      'sellerRegistered': p.sellerRegistered,
    };
    if (_same(values(before), values(next))) {
      return const Result.success(null);
    }
    final now = _clock.now();
    return _transactions.runResult<void>(() async {
      (await _preferences.save(next, now)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'tax_preferences',
          entityId: 'settings',
          action: 'updated',
          summary: 'Tax preferences updated.',
          occurredAt: now,
          previousValues: values(before),
          newValues: values(next),
        ),
      )).getOrThrow();
    });
  }

  Future<Result<String>> _save<T>({
    required TaxConfigKind kind,
    required T item,
    required String id,
    required String name,
    required Map<String, String> Function(T, TaxConfiguration) validate,
    required T? Function(TaxConfiguration, String) find,
    required Map<String, Object?> Function(T) values,
    required Future<Result<void>> Function(T, DateTime) write,
  }) async {
    final loaded = await _read.loadConfiguration();
    final config = loaded.valueOrNull;
    if (config == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final errors = validate(item, config);
    if (errors.isNotEmpty) {
      return Result.failure(
        ValidationFailure('Please correct the highlighted fields.', fieldErrors: errors),
      );
    }
    final existing = find(config, id);
    final now = _clock.now();
    final after = values(item);
    final before = existing == null ? null : values(existing);
    if (before != null && _same(before, after)) {
      return Result.success(id);
    }
    final previous = <String, Object?>{};
    final next = <String, Object?>{};
    for (final key in after.keys) {
      if (before == null || before[key] != after[key]) {
        previous[key] = before?[key];
        next[key] = after[key];
      }
    }
    final saved = await _transactions.runResult<void>(() async {
      (await write(item, now)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: kind.entityType,
          entityId: id,
          action: existing == null ? 'created' : 'updated',
          summary: existing == null
              ? '${_label(kind)} "$name" created.'
              : '${_label(kind)} "$name" updated: ${next.keys.join(', ')}.',
          occurredAt: now,
          previousValues: before == null ? null : previous,
          newValues: next,
        ),
      )).getOrThrow();
    });
    return saved.isFailure ? Result.failure(saved.failureOrNull!) : Result.success(id);
  }

  static bool _same(Map<String, Object?> a, Map<String, Object?> b) {
    for (final key in b.keys) {
      if (a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  static String _label(TaxConfigKind kind) => switch (kind) {
    TaxConfigKind.regime => 'Tax system',
    TaxConfigKind.jurisdiction => 'Tax place',
    TaxConfigKind.category => 'Tax category',
    TaxConfigKind.profile => 'Tax profile',
    TaxConfigKind.override => 'Tax override',
    TaxConfigKind.rule => 'Tax rule',
    TaxConfigKind.component => 'Tax component',
  };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
