/// Kinds of stock ledger entries. [dbName] is the stored value.
enum StockMovementType {
  openingStock('openingStock', inbound: true),
  purchase('purchase', inbound: true),
  sale('sale', inbound: false),
  salesReturn('salesReturn', inbound: true),
  purchaseReturn('purchaseReturn', inbound: false),
  adjustmentIn('adjustmentIn', inbound: true),
  adjustmentOut('adjustmentOut', inbound: false),
  reversal('reversal', inbound: null);

  const StockMovementType(this.dbName, {required this.inbound});

  /// Value stored in `stock_movements.movement_type`.
  final String dbName;

  /// `true` if the type always increases stock, `false` if it always
  /// decreases it, `null` if either (reversals).
  final bool? inbound;

  /// Parses a stored value.
  static StockMovementType fromDbName(String value) =>
      StockMovementType.values.firstWhere(
        (type) => type.dbName == value,
        orElse: () =>
            throw ArgumentError.value(value, 'value', 'Unknown movement type'),
      );

  /// Short label for the UI.
  String get label => switch (this) {
    openingStock => 'Opening stock',
    purchase => 'Purchase',
    sale => 'Sale',
    salesReturn => 'Sales return',
    purchaseReturn => 'Purchase return',
    adjustmentIn => 'Stock in',
    adjustmentOut => 'Stock out',
    reversal => 'Reversal',
  };
}
