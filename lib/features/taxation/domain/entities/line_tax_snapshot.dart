import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';

/// One frozen tax component of a document line.
final class TaxSnapshotComponent extends Equatable {
  /// Creates a component snapshot.
  const TaxSnapshotComponent({
    required this.order,
    required this.ruleId,
    required this.componentId,
    required this.name,
    required this.type,
    required this.method,
    required this.taxableMinor,
    required this.amountMinor,
    required this.isCompound,
    required this.isRecoverable,
    this.rateBasisPoints,
    this.fixedAmountMinor,
  });

  /// Reads a component from its JSON map.
  factory TaxSnapshotComponent.fromJson(Map<String, Object?> json) =>
      TaxSnapshotComponent(
        order: json['order']! as int,
        ruleId: json['ruleId']! as String,
        componentId: json['componentId']! as String,
        name: json['name']! as String,
        type: json['type']! as String,
        method: json['method']! as String,
        rateBasisPoints: json['rateBp'] as int?,
        fixedAmountMinor: json['fixedMinor'] as int?,
        taxableMinor: json['taxableMinor']! as int,
        amountMinor: json['amountMinor']! as int,
        isCompound: json['compound']! as bool,
        isRecoverable: json['recoverable']! as bool,
      );

  /// Position in the calculation (1-based).
  final int order;

  /// Rule that produced it.
  final String ruleId;

  /// Component that produced it.
  final String componentId;

  /// Name at calculation time.
  final String name;

  /// Component type code at calculation time.
  final String type;

  /// `percentage` or `fixed`.
  final String method;

  /// Rate in basis points, for percentage components.
  final int? rateBasisPoints;

  /// Per-unit amount in minor units, for fixed components.
  final int? fixedAmountMinor;

  /// Base the component was applied to.
  final int taxableMinor;

  /// Tax amount.
  final int amountMinor;

  /// Whether it was compounded on earlier components.
  final bool isCompound;

  /// Whether the tax can be claimed back.
  final bool isRecoverable;

  /// JSON map with a fixed key order (the encoding is canonical).
  Map<String, Object?> toJson() => {
    'order': order,
    'ruleId': ruleId,
    'componentId': componentId,
    'name': name,
    'type': type,
    'method': method,
    'rateBp': rateBasisPoints,
    'fixedMinor': fixedAmountMinor,
    'taxableMinor': taxableMinor,
    'amountMinor': amountMinor,
    'compound': isCompound,
    'recoverable': isRecoverable,
  };

  @override
  List<Object?> get props => [
    order,
    ruleId,
    componentId,
    name,
    type,
    method,
    rateBasisPoints,
    fixedAmountMinor,
    taxableMinor,
    amountMinor,
    isCompound,
    isRecoverable,
  ];
}

/// Everything about how a document line was taxed, frozen when the line is
/// saved and immutable once the document is posted. Later changes to tax
/// rules, categories or rates never reach it.
final class LineTaxSnapshot extends Equatable {
  /// Creates a snapshot.
  const LineTaxSnapshot({
    required this.regimeId,
    required this.taxProfileId,
    required this.taxCategoryId,
    required this.treatment,
    required this.pricingMode,
    required this.transactionDate,
    required this.placeOfSupply,
    required this.supplyRelation,
    required this.ruleIds,
    required this.reverseChargeTaxMinor,
    required this.components,
    this.treatmentReason,
  });

  /// Freezes a calculation result.
  factory LineTaxSnapshot.fromResult(TaxCalculationResult r) =>
      LineTaxSnapshot(
        regimeId: r.regimeId,
        taxProfileId: r.taxProfileId,
        taxCategoryId: r.taxCategoryId,
        treatment: r.treatment.code,
        treatmentReason: r.treatmentReason,
        pricingMode: r.pricingMode.code,
        transactionDate: DateTime.utc(
          r.transactionDate.year,
          r.transactionDate.month,
          r.transactionDate.day,
        ),
        placeOfSupply: r.placeOfSupply.toString(),
        supplyRelation: r.supplyRelation.code,
        ruleIds: List.unmodifiable(r.ruleIds),
        reverseChargeTaxMinor: r.reverseChargeTax.minorUnits,
        components: List.unmodifiable([
          for (var i = 0; i < r.components.length; i++)
            TaxSnapshotComponent(
              order: i + 1,
              ruleId: r.components[i].ruleId,
              componentId: r.components[i].componentId,
              name: r.components[i].name,
              type: r.components[i].type.code,
              method: r.components[i].method.code,
              rateBasisPoints: r.components[i].rateBasisPoints,
              fixedAmountMinor: r.components[i].fixedAmount?.minorUnits,
              taxableMinor: r.components[i].taxableAmount.minorUnits,
              amountMinor: r.components[i].amount.minorUnits,
              isCompound: r.components[i].isCompound,
              isRecoverable: r.components[i].isRecoverable,
            ),
        ]),
      );

  /// Reads a snapshot from text written by [encode].
  factory LineTaxSnapshot.decode(String text) {
    final json = jsonDecode(text) as Map<String, Object?>;
    return LineTaxSnapshot(
      regimeId: json['regimeId']! as String,
      taxProfileId: json['profileId']! as String,
      taxCategoryId: json['categoryId']! as String,
      treatment: json['treatment']! as String,
      treatmentReason: json['treatmentReason'] as String?,
      pricingMode: json['pricingMode']! as String,
      transactionDate: DateTime.parse(json['date']! as String),
      placeOfSupply: json['placeOfSupply']! as String,
      supplyRelation: json['supplyRelation']! as String,
      ruleIds: List.unmodifiable(
        (json['ruleIds']! as List<Object?>).cast<String>(),
      ),
      reverseChargeTaxMinor: json['reverseChargeMinor']! as int,
      components: List.unmodifiable([
        for (final c in json['components']! as List<Object?>)
          TaxSnapshotComponent.fromJson(
            (c! as Map<Object?, Object?>).cast<String, Object?>(),
          ),
      ]),
    );
  }

  /// Regime at calculation time.
  final String regimeId;

  /// Profile used.
  final String taxProfileId;

  /// Category used.
  final String taxCategoryId;

  /// Treatment code (`standard_rated`, `exempt`, ...).
  final String treatment;

  /// Why the treatment differs from the category default, if it does.
  final String? treatmentReason;

  /// `inclusive` or `exclusive`.
  final String pricingMode;

  /// Date the line was taxed on (UTC midnight).
  final DateTime transactionDate;

  /// Place of supply as text, for example `IN-KA`.
  final String placeOfSupply;

  /// Derived seller / place relation code.
  final String supplyRelation;

  /// Rules that contributed components.
  final List<String> ruleIds;

  /// Tax computed under reverse charge (not on the invoice total).
  final int reverseChargeTaxMinor;

  /// The components, in calculation order.
  final List<TaxSnapshotComponent> components;

  /// Canonical JSON text: fixed key order, no extra whitespace, so equal
  /// snapshots always encode to identical text.
  String encode() => jsonEncode({
    'v': 1,
    'regimeId': regimeId,
    'profileId': taxProfileId,
    'categoryId': taxCategoryId,
    'treatment': treatment,
    'treatmentReason': treatmentReason,
    'pricingMode': pricingMode,
    'date': transactionDate.toIso8601String(),
    'placeOfSupply': placeOfSupply,
    'supplyRelation': supplyRelation,
    'ruleIds': ruleIds,
    'reverseChargeMinor': reverseChargeTaxMinor,
    'components': [for (final c in components) c.toJson()],
  });

  @override
  List<Object?> get props => [
    regimeId,
    taxProfileId,
    taxCategoryId,
    treatment,
    treatmentReason,
    pricingMode,
    transactionDate,
    placeOfSupply,
    supplyRelation,
    ruleIds,
    reverseChargeTaxMinor,
    components,
  ];
}
