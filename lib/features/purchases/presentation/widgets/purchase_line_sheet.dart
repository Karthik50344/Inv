import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/presentation/widgets/app_button.dart';

/// Validates and stores a line; returns field errors (empty = accepted).
typedef SaveLineCallback =
    Future<Map<String, String>> Function(
      PurchaseLineInput input,
    );

/// Opens the add/edit line sheet. Resolves to `true` when a line was saved.
Future<bool> showPurchaseLineSheet(
  BuildContext context, {
  required List<Product> products,
  required Map<String, UnitOfMeasure> units,
  required CurrencyConfig currency,
  required SaveLineCallback onSave,
  PurchaseLineInput? initial,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PurchaseLineSheet(
      products: products,
      units: units,
      currency: currency,
      onSave: onSave,
      initial: initial,
    ),
  );
  return saved ?? false;
}

/// Form for one purchase line: product, quantity, price and discount.
class PurchaseLineSheet extends StatefulWidget {
  /// Creates the sheet.
  const PurchaseLineSheet({
    required this.products,
    required this.units,
    required this.currency,
    required this.onSave,
    this.initial,
    super.key,
  });

  /// Products that can be sold.
  final List<Product> products;

  /// Units by id (for symbols and precision hints).
  final Map<String, UnitOfMeasure> units;

  /// Active currency.
  final CurrencyConfig currency;

  /// Validates and stores the line.
  final SaveLineCallback onSave;

  /// Existing line when editing.
  final PurchaseLineInput? initial;

  @override
  State<PurchaseLineSheet> createState() => _PurchaseLineSheetState();
}

class _PurchaseLineSheetState extends State<PurchaseLineSheet> {
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  String? _productId;
  DiscountKind _kind = DiscountKind.none;
  Map<String, String> _errors = const {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _productId = initial?.productId;
    _kind = initial?.discountKind ?? DiscountKind.none;
    _quantity = TextEditingController(text: initial?.quantity ?? '');
    _price = TextEditingController(text: initial?.unitPrice ?? '');
    _discount = TextEditingController(text: initial?.discountValue ?? '');
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  Product? get _product {
    for (final product in widget.products) {
      if (product.id == _productId) {
        return product;
      }
    }
    return null;
  }

  Future<void> _save() async {
    final productId = _productId;
    if (productId == null) {
      setState(() => _errors = {'product': 'Choose a product.'});
      return;
    }
    setState(() => _saving = true);
    final errors = await widget.onSave(
      PurchaseLineInput(
        productId: productId,
        quantity: _quantity.text,
        unitPrice: _price.text,
        discountKind: _kind,
        discountValue: _discount.text,
      ),
    );
    if (!mounted) {
      return;
    }
    if (errors.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _errors = errors;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final unit = product == null ? null : widget.units[product.unitId];
    final places = unit?.decimalPlaces;
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: child,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? 'Add item' : 'Edit item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            gap(
              DropdownButtonFormField<String>(
                key: const Key('line_product'),
                initialValue: _productId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Product *',
                  errorText: _errors['product'],
                ),
                items: [
                  for (final p in widget.products)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.sku})'),
                    ),
                ],
                onChanged: (value) => setState(() => _productId = value),
              ),
            ),
            gap(
              TextField(
                key: const Key('line_quantity'),
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  suffixText: unit?.symbol,
                  helperText: places == null
                      ? null
                      : (places == 0
                            ? 'Whole numbers only.'
                            : 'Up to $places decimal places.'),
                  errorText: _errors['quantity'],
                ),
              ),
            ),
            gap(
              TextField(
                key: const Key('line_price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Unit price',
                  prefixText: '${widget.currency.currencyCode} ',
                  helperText: product == null
                      ? null
                      : 'Blank uses the purchase price '
                            '(${product.purchasePrice.toPlainString()})'
                            '${product.priceIncludesTax ? ', tax included' : ''}.',
                  errorText: _errors['unitPrice'],
                ),
              ),
            ),
            gap(
              SegmentedButton<DiscountKind>(
                key: const Key('line_discount_kind'),
                segments: const [
                  ButtonSegment(
                    value: DiscountKind.none,
                    label: Text('No discount'),
                  ),
                  ButtonSegment(value: DiscountKind.percent, label: Text('%')),
                  ButtonSegment(
                    value: DiscountKind.amount,
                    label: Text('Amount'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (value) =>
                    setState(() => _kind = value.first),
              ),
            ),
            if (_kind != DiscountKind.none)
              gap(
                TextField(
                  key: const Key('line_discount_value'),
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _kind == DiscountKind.percent
                        ? 'Discount (%)'
                        : 'Discount amount',
                    errorText: _errors['discount'],
                  ),
                ),
              ),
            AppButton(
              key: const Key('save_line'),
              label: widget.initial == null ? 'Add item' : 'Save item',
              expand: true,
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppDimensions.spaceSm),
          ],
        ),
      ),
    );
  }
}
