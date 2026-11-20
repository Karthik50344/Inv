import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Test-only data. The rates below are made-up numbers chosen to make the
/// arithmetic easy to check; they are not statements about any real law.
Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

final DateTime kJune2026 = DateTime.utc(2026, 6, 1);

const String kProfile = 'p1';
const String kCategory = 'c1';

const TaxRegime kRegime = TaxRegime(
  id: 'r1',
  name: 'Test regime',
  countryCode: 'IN',
  currencyCode: 'INR',
);

const TaxProfile kTaxProfile = TaxProfile(
  id: kProfile,
  name: 'Test profile',
  regimeId: 'r1',
  isDefault: true,
  defaultTaxCategoryId: kCategory,
);

TaxCategory category(
  String id, {
  TaxTreatment treatment = TaxTreatment.standardRated,
  bool isActive = true,
}) => TaxCategory(
  id: id,
  name: 'Category $id',
  code: id.toUpperCase(),
  defaultTaxTreatment: treatment,
  isActive: isActive,
);

TaxRule rule(
  String id, {
  String categoryId = kCategory,
  String? jurisdictionId,
  TaxTransactionType? transactionType,
  String? supplyType,
  String? customerTaxStatus,
  SupplyRelation relation = SupplyRelation.any,
  TaxCalculationMethod method = TaxCalculationMethod.percentage,
  bool stackable = false,
  DateTime? from,
  DateTime? until,
  int priority = 0,
}) => TaxRule(
  id: id,
  taxProfileId: kProfile,
  taxCategoryId: categoryId,
  jurisdictionId: jurisdictionId,
  transactionType: transactionType,
  supplyType: supplyType,
  customerTaxStatus: customerTaxStatus,
  supplyRelation: relation,
  calculationMethod: method,
  isStackable: stackable,
  effectiveFrom: from ?? DateTime.utc(2000),
  effectiveUntil: until,
  priority: priority,
);

TaxComponent component(
  String id,
  String ruleId, {
  String? name,
  TaxComponentType type = TaxComponentType.custom,
  int rate = 0,
  int order = 1,
  bool compound = false,
  int? fixed,
  bool recoverable = false,
}) => TaxComponent(
  id: id,
  taxRuleId: ruleId,
  name: name ?? id,
  componentType: type,
  rateBasisPoints: rate,
  calculationOrder: order,
  isCompound: compound,
  fixedAmountMinor: fixed,
  isRecoverable: recoverable,
);

TaxConfiguration config({
  List<TaxCategory>? categories,
  List<TaxRule> rules = const [],
  List<TaxComponent> components = const [],
  List<TaxJurisdiction> jurisdictions = const [],
  List<TaxOverride> overrides = const [],
  TaxProfile profile = kTaxProfile,
}) => TaxConfiguration(
  regimes: const [kRegime],
  jurisdictions: jurisdictions,
  categories: categories ?? [category(kCategory)],
  profiles: [profile],
  overrides: overrides,
  rules: rules,
  components: components,
);

TaxCalculationInput input({
  int gross = 10000,
  int quantity = 1,
  int? discount,
  PricingMode pricing = PricingMode.exclusive,
  String categoryId = kCategory,
  TaxTransactionType type = TaxTransactionType.sale,
  DateTime? date,
  TaxLocation seller = const TaxLocation(countryCode: 'IN', regionCode: 'KA'),
  TaxLocation place = const TaxLocation(countryCode: 'IN', regionCode: 'KA'),
  String? supplyType,
  String? customerStatus,
  bool sellerRegistered = true,
  TaxTreatment? treatmentOverride,
  String? overrideReference,
}) => TaxCalculationInput(
  taxProfileId: kProfile,
  taxCategoryId: categoryId,
  transactionType: type,
  transactionDate: date ?? kJune2026,
  pricingMode: pricing,
  sellerLocation: seller,
  placeOfSupply: place,
  grossAmount: inr(gross),
  quantity: Quantity.fromUnits(quantity),
  discount: discount == null ? null : inr(discount),
  supplyType: supplyType,
  customerTaxStatus: customerStatus,
  isSellerTaxRegistered: sellerRegistered,
  treatmentOverride: treatmentOverride,
  overrideReference: overrideReference,
);
