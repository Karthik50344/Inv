import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/presentation/support/tax_labels.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Opens a form as a bottom sheet.
Future<void> showTaxFormSheet(BuildContext context, Widget form) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => form,
    );

/// Shared behaviour of the tax forms: field errors from a failed save, a
/// saving state, and the common layout.
abstract class _TaxFormState<T extends StatefulWidget> extends State<T> {
  Map<String, String> errors = const {};
  bool saving = false;
  String? generalError;

  /// Runs [save]; closes the sheet on success, shows errors otherwise.
  Future<void> submit(Future<Failure?> Function() save) async {
    setState(() {
      saving = true;
      generalError = null;
    });
    final failure = await save();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      saving = false;
      if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
        errors = failure.fieldErrors;
      } else {
        generalError = failure.message;
      }
    });
  }

  Widget shell(String title, List<Widget> children, VoidCallback onSave, {String? help}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (help != null) ...[
              AppSpacing.gap4,
              Text(help, style: theme.textTheme.bodySmall),
            ],
            AppSpacing.gap16,
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s12), child: child),
            if (generalError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                child: Text(generalError!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ),
            AppButton(label: 'Save', loading: saving, expand: true, onPressed: saving ? null : onSave),
          ],
        ),
      ),
    );
  }

  Widget error(String key) => errors[key] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s4),
          child: Text(errors[key]!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
        );
}

String? _blank(String text) => text.trim().isEmpty ? null : text.trim();

// ---------------------------------------------------------------- regime

/// Create or edit a tax system.
class TaxRegimeForm extends StatefulWidget {
  /// Creates the form.
  const TaxRegimeForm({required this.id, required this.onSave, this.existing, this.defaultCurrency = '', super.key});

  /// Id for a new record.
  final String id;

  /// The record being edited.
  final TaxRegime? existing;

  /// Currency pre-filled for a new system.
  final String defaultCurrency;

  /// Saves; returns the failure or `null`.
  final Future<Failure?> Function(TaxRegime) onSave;

  @override
  State<TaxRegimeForm> createState() => _TaxRegimeFormState();
}

class _TaxRegimeFormState extends _TaxFormState<TaxRegimeForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _country = TextEditingController(text: widget.existing?.countryCode ?? '');
  late final _currency = TextEditingController(text: widget.existing?.currencyCode ?? widget.defaultCurrency);
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _currency.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => shell(
    widget.existing == null ? 'Add a tax system' : 'Edit tax system',
    [
      AppTextField(label: 'Name', hint: 'For example GST', controller: _name, errorText: errors['name']),
      AppTextField(label: 'Country code', hint: 'IN', controller: _country, errorText: errors['countryCode'], textCapitalization: TextCapitalization.characters),
      AppTextField(label: 'Currency code', hint: 'INR', controller: _currency, errorText: errors['currencyCode'], textCapitalization: TextCapitalization.characters),
      AppTextField(label: 'Notes (optional)', controller: _description),
      if (widget.existing != null)
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In use'), value: _active, onChanged: (v) => setState(() => _active = v)),
    ],
    () => submit(
      () => widget.onSave(
        TaxRegime(
          id: widget.existing?.id ?? widget.id,
          name: _name.text,
          countryCode: _country.text.trim().toUpperCase(),
          currencyCode: _currency.text.trim().toUpperCase(),
          description: _blank(_description.text),
          isActive: _active,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------- jurisdiction

/// Create or edit a place taxes depend on.
class TaxJurisdictionForm extends StatefulWidget {
  /// Creates the form.
  const TaxJurisdictionForm({required this.id, required this.configuration, required this.onSave, this.existing, super.key});

  /// Id for a new record.
  final String id;

  /// The configuration (for the lists of systems and parent places).
  final TaxConfiguration configuration;

  /// The record being edited.
  final TaxJurisdiction? existing;

  /// Saves; returns the failure or `null`.
  final Future<Failure?> Function(TaxJurisdiction) onSave;

  @override
  State<TaxJurisdictionForm> createState() => _TaxJurisdictionFormState();
}

class _TaxJurisdictionFormState extends _TaxFormState<TaxJurisdictionForm> {
  late String? _regime = widget.existing?.regimeId ?? widget.configuration.regimes.firstOrNull?.id;
  late String _type = widget.existing?.jurisdictionType.code ?? 'state';
  late String? _parent = widget.existing?.parentJurisdictionId;
  late final _country = TextEditingController(text: widget.existing?.countryCode ?? widget.configuration.regimes.firstOrNull?.countryCode ?? '');
  late final _region = TextEditingController(text: widget.existing?.regionCode ?? '');
  late final _name = TextEditingController(text: widget.existing?.regionName ?? '');
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _country.dispose();
    _region.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.configuration;
    final parents = c.jurisdictions.where((j) => j.id != widget.existing?.id).toList();
    return shell(
      widget.existing == null ? 'Add a place' : 'Edit place',
      [
        AppDropdown<String?>(
          label: 'Tax system',
          value: c.regime(_regime ?? '') == null ? null : _regime,
          errorText: errors['regimeId'],
          items: [for (final r in c.regimes) AppDropdownItem<String?>(value: r.id, label: r.name)],
          onChanged: (v) => setState(() => _regime = v),
        ),
        AppDropdown<String>(
          label: 'Kind of place',
          value: TaxLabels.jurisdictionTypes.containsKey(_type) ? _type : 'other',
          items: [for (final e in TaxLabels.jurisdictionTypes.entries) AppDropdownItem(value: e.key, label: e.value)],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        AppTextField(label: 'Country code', hint: 'IN', controller: _country, errorText: errors['countryCode'], textCapitalization: TextCapitalization.characters),
        AppTextField(label: 'State or region code (optional)', hint: 'KA', controller: _region, errorText: errors['regionCode'], textCapitalization: TextCapitalization.characters),
        AppTextField(label: 'Name (optional)', hint: 'Karnataka', controller: _name),
        AppDropdown<String?>(
          label: 'Inside (optional)',
          value: parents.any((j) => j.id == _parent) ? _parent : null,
          errorText: errors['parentJurisdictionId'],
          items: [
            const AppDropdownItem<String?>(value: null, label: 'Nothing: a top-level place'),
            for (final j in parents)
              AppDropdownItem<String?>(value: j.id, label: j.regionName ?? j.regionCode ?? j.countryCode),
          ],
          onChanged: (v) => setState(() => _parent = v),
        ),
        if (widget.existing != null)
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In use'), value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
      () => submit(
        () => widget.onSave(
          TaxJurisdiction(
            id: widget.existing?.id ?? widget.id,
            regimeId: _regime ?? '',
            countryCode: _country.text.trim().toUpperCase(),
            regionCode: _blank(_region.text)?.toUpperCase(),
            regionName: _blank(_name.text),
            jurisdictionType: JurisdictionType(_type),
            parentJurisdictionId: _parent,
            isActive: _active,
          ),
        ),
      ),
      help: 'Places let one tax apply in a state or city and another elsewhere.',
    );
  }
}

// -------------------------------------------------------------- category

/// Create or edit a tax category.
class TaxCategoryForm extends StatefulWidget {
  /// Creates the form.
  const TaxCategoryForm({required this.id, required this.onSave, this.existing, super.key});

  /// Id for a new record.
  final String id;

  /// The record being edited.
  final TaxCategory? existing;

  /// Saves; returns the failure or `null`.
  final Future<Failure?> Function(TaxCategory) onSave;

  @override
  State<TaxCategoryForm> createState() => _TaxCategoryFormState();
}

class _TaxCategoryFormState extends _TaxFormState<TaxCategoryForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late TaxTreatment _treatment = widget.existing?.defaultTaxTreatment ?? TaxTreatment.standardRated;
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => shell(
    widget.existing == null ? 'Add a tax category' : 'Edit tax category',
    [
      AppTextField(label: 'Name', hint: 'For example Standard rate', controller: _name, errorText: errors['name']),
      AppTextField(label: 'Short code', hint: 'STD', controller: _code, errorText: errors['code']),
      AppDropdown<TaxTreatment>(
        label: 'How it is taxed',
        value: _treatment,
        helper: TaxLabels.treatmentHelp(_treatment),
        items: [for (final t in TaxTreatment.values) AppDropdownItem(value: t, label: t.label)],
        onChanged: (v) => setState(() => _treatment = v ?? _treatment),
      ),
      AppTextField(label: 'Notes (optional)', controller: _description),
      if (widget.existing != null)
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In use'), value: _active, onChanged: (v) => setState(() => _active = v)),
    ],
    () => submit(
      () => widget.onSave(
        TaxCategory(
          id: widget.existing?.id ?? widget.id,
          name: _name.text,
          code: _code.text,
          description: _blank(_description.text),
          defaultTaxTreatment: _treatment,
          isActive: _active,
        ),
      ),
    ),
    help: 'Products are given a category; the rules decide the rate.',
  );
}

// --------------------------------------------------------------- profile

/// Create or edit a tax profile.
class TaxProfileForm extends StatefulWidget {
  /// Creates the form.
  const TaxProfileForm({required this.id, required this.configuration, required this.onSave, this.existing, super.key});

  /// Id for a new record.
  final String id;

  /// The configuration (for the lists of systems and categories).
  final TaxConfiguration configuration;

  /// The record being edited.
  final TaxProfile? existing;

  /// Saves; returns the failure or `null`.
  final Future<Failure?> Function(TaxProfile) onSave;

  @override
  State<TaxProfileForm> createState() => _TaxProfileFormState();
}

class _TaxProfileFormState extends _TaxFormState<TaxProfileForm> {
  late String? _regime = widget.existing?.regimeId ?? widget.configuration.regimes.firstOrNull?.id;
  late String? _category = widget.existing?.defaultTaxCategoryId;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late bool _default = widget.existing?.isDefault ?? widget.configuration.profiles.isEmpty;
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.configuration;
    final cats = c.categories.where((x) => x.isActive || x.id == _category).toList();
    return shell(
      widget.existing == null ? 'Add a tax profile' : 'Edit tax profile',
      [
        AppTextField(label: 'Name', hint: 'For example Main business', controller: _name, errorText: errors['name']),
        AppDropdown<String?>(
          label: 'Tax system',
          value: c.regime(_regime ?? '') == null ? null : _regime,
          errorText: errors['regimeId'],
          items: [for (final r in c.regimes) AppDropdownItem<String?>(value: r.id, label: r.name)],
          onChanged: (v) => setState(() => _regime = v),
        ),
        AppDropdown<String?>(
          label: 'Category for products without one',
          value: cats.any((x) => x.id == _category) ? _category : null,
          errorText: errors['defaultTaxCategoryId'],
          items: [
            const AppDropdownItem<String?>(value: null, label: 'None: every product needs a category'),
            for (final x in cats) AppDropdownItem<String?>(value: x.id, label: x.name),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        AppTextField(label: 'Notes (optional)', controller: _description),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use for new documents'),
          subtitle: const Text('Only one profile is the default.'),
          value: _default,
          onChanged: (v) => setState(() => _default = v),
        ),
        if (widget.existing != null)
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In use'), value: _active, onChanged: (v) => setState(() => _active = v)),
        error('isActive'),
      ],
      () => submit(
        () => widget.onSave(
          TaxProfile(
            id: widget.existing?.id ?? widget.id,
            name: _name.text,
            regimeId: _regime ?? '',
            description: _blank(_description.text),
            isDefault: _default,
            defaultTaxCategoryId: _category,
            isActive: _active,
          ),
        ),
      ),
      help: 'A profile is the set of rules used when documents are made.',
    );
  }
}

// -------------------------------------------------------------- override

/// Create or edit a product tax override.
class TaxOverrideForm extends StatefulWidget {
  /// Creates the form.
  const TaxOverrideForm({required this.id, required this.configuration, required this.onSave, this.existing, super.key});

  /// Id for a new record.
  final String id;

  /// The configuration (for the list of categories).
  final TaxConfiguration configuration;

  /// The record being edited.
  final TaxOverride? existing;

  /// Saves; returns the failure or `null`.
  final Future<Failure?> Function(TaxOverride) onSave;

  @override
  State<TaxOverrideForm> createState() => _TaxOverrideFormState();
}

class _TaxOverrideFormState extends _TaxFormState<TaxOverrideForm> {
  late String? _category = widget.existing?.taxCategoryId;
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _reason = TextEditingController(text: widget.existing?.reason ?? '');
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.configuration.categories.where((x) => x.isActive || x.id == _category).toList();
    return shell(
      widget.existing == null ? 'Add an override' : 'Edit override',
      [
        AppTextField(label: 'Name', hint: 'For example Export goods', controller: _name, errorText: errors['name']),
        AppDropdown<String?>(
          label: 'Tax category it uses',
          value: cats.any((x) => x.id == _category) ? _category : null,
          errorText: errors['taxCategoryId'],
          items: [for (final x in cats) AppDropdownItem<String?>(value: x.id, label: '${x.name} (${x.defaultTaxTreatment.label})')],
          onChanged: (v) => setState(() => _category = v),
        ),
        AppTextField(label: 'Why is this different?', hint: 'For example export certificate', controller: _reason, errorText: errors['reason']),
        if (widget.existing != null)
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In use'), value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
      () => submit(
        () => widget.onSave(
          TaxOverride(
            id: widget.existing?.id ?? widget.id,
            name: _name.text,
            taxCategoryId: _category ?? '',
            reason: _reason.text,
            isActive: _active,
          ),
        ),
      ),
      help: 'An override is chosen on a product and replaces its category. The reason is kept for your auditor.',
    );
  }
}

// ------------------------------------------------------------------ rule

/// Create or edit a tax rule. The profile and category of an existing rule
/// cannot change.
class TaxRuleForm extends StatefulWidget {
  /// Creates the form.
  const TaxRuleForm({required this.id, required this.configuration, required this.onSave, this.existing, this.initialCategoryId, super.key});

  /// Id for a new record.
  final String id;

  /// The configuration (for the lists).
  final TaxConfiguration configuration;

  /// The record being edited.
  final TaxRule? existing;

  /// Category pre-selected for a new rule.
  final String? initialCategoryId;

  /// Saves; returns the failure or `null`.
  final Future<Failure?> Function(TaxRule) onSave;

  @override
  State<TaxRuleForm> createState() => _TaxRuleFormState();
}

class _TaxRuleFormState extends _TaxFormState<TaxRuleForm> {
  late String? _profile = widget.existing?.taxProfileId ?? widget.configuration.defaultProfile?.id ?? widget.configuration.profiles.firstOrNull?.id;
  late String? _category = widget.existing?.taxCategoryId ?? widget.initialCategoryId;
  late String? _place = widget.existing?.jurisdictionId;
  late TaxTransactionType? _transaction = widget.existing?.transactionType;
  late String? _supply = widget.existing?.supplyType;
  late SupplyRelation _relation = widget.existing?.supplyRelation ?? SupplyRelation.any;
  late TaxCalculationMethod _method = widget.existing?.calculationMethod ?? TaxCalculationMethod.percentage;
  late bool _stack = widget.existing?.isStackable ?? false;
  late DateTime _from = widget.existing?.effectiveFrom ?? DateTime.utc(DateTime.now().year);
  late DateTime? _until = widget.existing?.effectiveUntil;
  late final _status = TextEditingController(text: widget.existing?.customerTaxStatus ?? '');
  late final _priority = TextEditingController(text: '${widget.existing?.priority ?? 0}');
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _status.dispose();
    _priority.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.configuration;
    final locked = widget.existing != null;
    final cats = c.categories.where((x) => x.defaultTaxTreatment.computesTax && (x.isActive || x.id == _category)).toList();
    return shell(
      widget.existing == null ? 'Add a tax rule' : 'Edit tax rule',
      [
        AppDropdown<String?>(
          label: 'Tax profile',
          value: c.profile(_profile ?? '') == null ? null : _profile,
          errorText: errors['taxProfileId'],
          items: [for (final p in c.profiles) AppDropdownItem<String?>(value: p.id, label: p.name)],
          onChanged: locked ? null : (v) => setState(() => _profile = v),
        ),
        AppDropdown<String?>(
          label: 'Tax category',
          value: cats.any((x) => x.id == _category) ? _category : null,
          errorText: errors['taxCategoryId'],
          helper: cats.isEmpty ? 'Add a category that charges tax first.' : null,
          items: [for (final x in cats) AppDropdownItem<String?>(value: x.id, label: x.name)],
          onChanged: locked ? null : (v) => setState(() => _category = v),
        ),
        AppDropdown<String?>(
          label: 'Where it applies',
          value: c.jurisdiction(_place ?? '') == null ? null : _place,
          errorText: errors['jurisdictionId'],
          items: [
            const AppDropdownItem<String?>(value: null, label: 'Everywhere'),
            for (final j in c.jurisdictions) AppDropdownItem<String?>(value: j.id, label: j.regionName ?? j.regionCode ?? j.countryCode),
          ],
          onChanged: (v) => setState(() => _place = v),
        ),
        AppDropdown<SupplyRelation>(
          label: 'Seller and buyer location',
          value: _relation,
          items: [for (final r in SupplyRelation.values) AppDropdownItem(value: r, label: TaxLabels.relation(r))],
          onChanged: (v) => setState(() => _relation = v ?? _relation),
        ),
        AppDropdown<TaxTransactionType?>(
          label: 'For',
          value: _transaction,
          items: [
            for (final t in <TaxTransactionType?>[null, ...TaxTransactionType.values])
              AppDropdownItem<TaxTransactionType?>(value: t, label: TaxLabels.transactionType(t)),
          ],
          onChanged: (v) => setState(() => _transaction = v),
        ),
        AppDropdown<String?>(
          label: 'Goods or services',
          value: const {'goods', 'services'}.contains(_supply) ? _supply : null,
          items: const [
            AppDropdownItem<String?>(value: null, label: 'Either'),
            AppDropdownItem<String?>(value: 'goods', label: 'Goods'),
            AppDropdownItem<String?>(value: 'services', label: 'Services'),
          ],
          onChanged: (v) => setState(() => _supply = v),
        ),
        AppTextField(label: 'Customer type (optional)', hint: 'For example registered', controller: _status, errorText: errors['customerTaxStatus']),
        AppDropdown<TaxCalculationMethod>(
          label: 'How the tax is worked out',
          value: _method,
          items: [for (final m in TaxCalculationMethod.values) AppDropdownItem(value: m, label: TaxLabels.method(m))],
          onChanged: widget.existing == null ? (v) => setState(() => _method = v ?? _method) : null,
        ),
        AppButton(
          label: 'From ${DateFormatter.date(_from)}',
          icon: Icons.event_outlined,
          variant: AppButtonVariant.outlined,
          expand: true,
          onPressed: () async {
            final d = await _pick(_from);
            if (d != null) {
              setState(() => _from = DateTime.utc(d.year, d.month, d.day));
            }
          },
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: _until == null ? 'No end date' : 'Until ${DateFormatter.date(_until!)}',
                icon: Icons.event_busy_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: () async {
                  final d = await _pick(_until ?? _from);
                  if (d != null) {
                    setState(() => _until = DateTime.utc(d.year, d.month, d.day));
                  }
                },
              ),
            ),
            if (_until != null) IconButton(tooltip: 'Remove end date', icon: const Icon(Icons.close), onPressed: () => setState(() => _until = null)),
          ],
        ),
        error('effectiveUntil'),
        AppTextField(label: 'Priority', helper: 'When two rules could apply, the higher number wins.', controller: _priority, keyboardType: const TextInputType.numberWithOptions(signed: true), errorText: errors['priority']),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Add to the main rule'),
          subtitle: const Text('For a tax charged together with another, such as a county tax on top of a state tax.'),
          value: _stack,
          onChanged: (v) => setState(() => _stack = v),
        ),
        if (widget.existing != null)
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In use'), value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
      () => submit(
        () => widget.onSave(
          TaxRule(
            id: widget.existing?.id ?? widget.id,
            taxProfileId: _profile ?? '',
            taxCategoryId: _category ?? '',
            jurisdictionId: _place,
            transactionType: _transaction,
            customerTaxStatus: _blank(_status.text),
            supplyType: _supply,
            supplyRelation: _relation,
            calculationMethod: _method,
            isStackable: _stack,
            effectiveFrom: _from,
            effectiveUntil: _until,
            priority: int.tryParse(_priority.text.trim()) ?? 0,
            isActive: _active,
          ),
        ),
      ),
      help: 'A rule says which tax lines apply, where and from when. Add the tax lines (such as CGST 9%) after saving.',
    );
  }
}

// ------------------------------------------------------------- component

/// Create or edit one tax line of a rule.
class TaxComponentForm extends StatefulWidget {
  /// Creates the form.
  const TaxComponentForm({
    required this.id,
    required this.rule,
    required this.nextOrder,
    required this.currencyDecimals,
    required this.onSave,
    this.existing,
    super.key,
  });

  /// Id for a new record.
  final String id;

  /// The rule the component belongs to.
  final TaxRule rule;

  /// Suggested order for a new component.
  final int nextOrder;

  /// Decimal places of the active currency.
  final int currencyDecimals;

  /// The record being edited.
  final TaxComponent? existing;

  /// Saves; returns the failure or `null`.
  final Future<Failure?> Function(TaxComponent) onSave;

  @override
  State<TaxComponentForm> createState() => _TaxComponentFormState();
}

class _TaxComponentFormState extends _TaxFormState<TaxComponentForm> {
  late String _type = widget.existing?.componentType.code ?? 'custom';
  late final _custom = TextEditingController(
    text: TaxLabels.componentTypes.containsKey(widget.existing?.componentType.code ?? 'custom') ? '' : widget.existing!.componentType.code,
  );
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _rate = TextEditingController(
    text: widget.existing == null || widget.rule.calculationMethod != TaxCalculationMethod.percentage
        ? ''
        : TaxLabels.percent(widget.existing!.rateBasisPoints).replaceAll('%', ''),
  );
  late final _fixed = TextEditingController(
    text: widget.existing?.fixedAmountMinor == null ? '' : TaxLabels.minorText(widget.existing!.fixedAmountMinor!, widget.currencyDecimals),
  );
  late final _order = TextEditingController(text: '${widget.existing?.calculationOrder ?? widget.nextOrder}');
  late bool _compound = widget.existing?.isCompound ?? false;
  late bool _recoverable = widget.existing?.isRecoverable ?? false;
  late bool _active = widget.existing?.isActive ?? true;

  bool get _isOther => !TaxLabels.componentTypes.containsKey(_type) || _type == 'custom';

  @override
  void initState() {
    super.initState();
    if (!TaxLabels.componentTypes.containsKey(_type)) {
      _type = 'custom';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    _name.dispose();
    _rate.dispose();
    _fixed.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.rule.calculationMethod == TaxCalculationMethod.percentage;
    return shell(
      widget.existing == null ? 'Add a tax line' : 'Edit tax line',
      [
        AppTextField(label: 'Name on invoices', hint: 'For example CGST', controller: _name, errorText: errors['name']),
        AppDropdown<String>(
          label: 'Kind of tax',
          value: _type,
          items: [for (final e in TaxLabels.componentTypes.entries) AppDropdownItem(value: e.key, label: e.value)],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        if (_isOther)
          AppTextField(
            label: 'Kind of tax (your own)',
            hint: 'custom',
            controller: _custom,
            errorText: errors['componentType'],
          ),
        if (percentage)
          AppTextField(label: 'Rate (%)', hint: '9', controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), errorText: errors['rateBasisPoints'])
        else
          AppTextField(label: 'Amount per unit', controller: _fixed, keyboardType: const TextInputType.numberWithOptions(decimal: true), errorText: errors['fixedAmountMinor']),
        AppTextField(label: 'Order', helper: 'Lines are worked out in this order.', controller: _order, keyboardType: TextInputType.number, errorText: errors['calculationOrder']),
        if (percentage)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Charged on the price plus earlier taxes'),
            subtitle: const Text('Tax on tax (compound).'),
            value: _compound,
            onChanged: (v) => setState(() => _compound = v),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Can be claimed back on purchases'),
          value: _recoverable,
          onChanged: (v) => setState(() => _recoverable = v),
        ),
        if (widget.existing != null)
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('In use'), value: _active, onChanged: (v) => setState(() => _active = v)),
        error('isCompound'),
      ],
      () {
        if (percentage && TaxLabels.parsePercent(_rate.text) == null) {
          setState(() => errors = {'rateBasisPoints': 'Enter a percentage from 0 to 1000, with up to two decimals.'});
          return;
        }
        if (!percentage && TaxLabels.parseMinor(_fixed.text, widget.currencyDecimals) == null) {
          setState(() => errors = {'fixedAmountMinor': 'Enter the amount with up to ${widget.currencyDecimals} decimals.'});
          return;
        }
        submit(
          () => widget.onSave(
            TaxComponent(
              id: widget.existing?.id ?? widget.id,
              taxRuleId: widget.rule.id,
              name: _name.text,
              componentType: TaxComponentType(_isOther && _custom.text.trim().isNotEmpty ? _custom.text.trim().toLowerCase() : _type),
              rateBasisPoints: percentage ? TaxLabels.parsePercent(_rate.text)! : 0,
              fixedAmountMinor: percentage ? null : TaxLabels.parseMinor(_fixed.text, widget.currencyDecimals),
              calculationOrder: int.tryParse(_order.text.trim()) ?? 0,
              isCompound: percentage && _compound,
              isRecoverable: _recoverable,
              isActive: _active,
            ),
          ),
        );
      },
    );
  }
}
