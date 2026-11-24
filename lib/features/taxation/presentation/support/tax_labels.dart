import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';

/// Plain-language texts and number parsing for the tax screens. The words
/// avoid tax jargon where a plain phrase exists.
abstract final class TaxLabels {
  /// `900` -> `9%`, `950` -> `9.5%`, `1` -> `0.01%`.
  static String percent(int basisPoints) {
    final whole = basisPoints ~/ 100;
    final fraction = basisPoints % 100;
    if (fraction == 0) {
      return '$whole%';
    }
    final text = fraction.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '');
    return '$whole.$text%';
  }

  /// `9`, `9.5`, `0,5` -> basis points; `null` when it is not a percentage
  /// with at most two decimals between 0 and 1000.
  static int? parsePercent(String text) {
    final cleaned = text.trim().replaceAll(',', '.').replaceAll('%', '');
    final m = RegExp(r'^(\d{1,4})(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (m == null) {
      return null;
    }
    final whole = int.parse(m.group(1)!);
    final fraction = int.parse((m.group(2) ?? '').padRight(2, '0'));
    final value = whole * 100 + fraction;
    return value > 100000 ? null : value;
  }

  /// An amount in minor units from text with up to [decimals] decimals.
  static int? parseMinor(String text, int decimals) {
    final cleaned = text.trim().replaceAll(',', '.');
    final m = RegExp(r'^(\d{1,12})(?:\.(\d{1,9}))?$').firstMatch(cleaned);
    if (m == null) {
      return null;
    }
    final fraction = m.group(2) ?? '';
    if (fraction.length > decimals) {
      return null;
    }
    return int.parse(m.group(1)! + fraction.padRight(decimals, '0'));
  }

  /// Minor units as text (`1250` with 2 decimals -> `12.50`).
  static String minorText(int minor, int decimals) {
    if (decimals == 0) {
      return '$minor';
    }
    final digits = minor.toString().padLeft(decimals + 1, '0');
    return '${digits.substring(0, digits.length - decimals)}.'
        '${digits.substring(digits.length - decimals)}';
  }

  /// A transaction type in words (`null` = any).
  static String transactionType(TaxTransactionType? type) => switch (type) {
    null => 'Any transaction',
    TaxTransactionType.sale => 'Sales',
    TaxTransactionType.purchase => 'Purchases',
    TaxTransactionType.salesReturn => 'Sales returns',
    TaxTransactionType.purchaseReturn => 'Purchase returns',
  };

  /// A supply relation in words.
  static String relation(SupplyRelation relation) => switch (relation) {
    SupplyRelation.any => 'Any location',
    SupplyRelation.intra => 'Same state or region',
    SupplyRelation.inter => 'Different state or region, same country',
    SupplyRelation.crossBorder => 'Different countries',
  };

  /// A calculation method in words.
  static String method(TaxCalculationMethod method) => switch (method) {
    TaxCalculationMethod.percentage => 'Percentage of the price',
    TaxCalculationMethod.fixed => 'Fixed amount per unit',
  };

  /// What a treatment means for the owner.
  static String treatmentHelp(TaxTreatment treatment) => switch (treatment) {
    TaxTreatment.standardRated => 'Tax is charged at the regular rate. Needs a rule.',
    TaxTreatment.reducedRated => 'Tax is charged at a lower rate. Needs a rule.',
    TaxTreatment.zeroRated => 'The rate is zero but the sale is still reported. No rule needed.',
    TaxTreatment.exempt => 'No tax by law. Reported as exempt. No rule needed.',
    TaxTreatment.outOfScope => 'Outside this tax. No rule needed.',
    TaxTreatment.reverseCharge => 'The buyer accounts for the tax; it is not added to the invoice. Needs a rule.',
  };

  /// Component types offered in the form (any other code can be typed).
  static const Map<String, String> componentTypes = {
    'cgst': 'CGST',
    'sgst': 'SGST',
    'igst': 'IGST',
    'utgst': 'UTGST',
    'gst': 'GST',
    'vat': 'VAT',
    'sales_tax': 'Sales tax',
    'hst': 'HST',
    'pst': 'PST',
    'qst': 'QST',
    'cess': 'Cess',
    'custom': 'Other',
  };

  /// Jurisdiction levels offered in the form.
  static const Map<String, String> jurisdictionTypes = {
    'country': 'Country',
    'state': 'State',
    'union_territory': 'Union territory',
    'province': 'Province',
    'county': 'County',
    'city': 'City',
    'other': 'Other',
  };

  /// The tax lines of a rule in words: `CGST 9% + SGST 9%`, or `No tax
  /// lines yet`.
  static String ruleLines(TaxConfiguration config, TaxRule rule, {int decimals = 2}) {
    final lines = config.componentsOf(rule.id);
    if (lines.isEmpty) {
      return 'No tax lines yet';
    }
    return lines
        .map(
          (c) => rule.calculationMethod == TaxCalculationMethod.percentage
              ? '${c.name} ${percent(c.rateBasisPoints)}'
              : '${c.name} ${minorText(c.fixedAmountMinor ?? 0, decimals)} per unit',
        )
        .join(' + ');
  }

  /// A place's display name.
  static String place(TaxConfiguration config, String? id) {
    if (id == null) {
      return 'Everywhere';
    }
    final j = config.jurisdiction(id);
    return j == null ? 'Unknown place' : (j.regionName ?? j.regionCode ?? j.countryCode);
  }
}
