import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Shows what a backup contains and asks for explicit confirmation before
/// the current data is replaced. Resolves to `true` only when confirmed.
///
/// With [firstSetup] (a new install with nothing to lose) the wording is
/// calmer and the "I understand" checkbox is not needed.
Future<bool> showRestoreConfirmationDialog(
  BuildContext context,
  BackupPreview preview, {
  bool firstSetup = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RestoreDialog(preview: preview, firstSetup: firstSetup),
  );
  return confirmed ?? false;
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.preview, required this.firstSetup});

  final BackupPreview preview;
  final bool firstSetup;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  late bool _understood = widget.firstSetup;

  static const Map<String, String> _labels = {
    'products': 'Products',
    'customers': 'Customers',
    'suppliers': 'Suppliers',
    'purchase_invoices': 'Purchase invoices',
    'sales_invoices': 'Sales invoices',
    'payments': 'Payments',
    'expenses': 'Expenses',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final danger = (widget.firstSetup ? AppTone.brand : AppTone.danger)
        .colors(context);
    final manifest = widget.preview.staged.manifest;
    final counts = widget.preview.inspection.recordCounts;
    final created = DateFormatter.dateTime(manifest.createdAt);
    return AlertDialog(
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: danger.container,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            widget.firstSetup
                ? Icons.restore
                : Icons.warning_amber_rounded,
            color: danger.onContainer,
          ),
        ),
      ),
      iconPadding: const EdgeInsets.only(top: AppSpacing.s24),
      title: Text(
        widget.firstSetup ? 'Restore this backup?' : 'Replace your data?',
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.preview.staged.sourceName,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Created $created · app ${manifest.appVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            AppSpacing.gap12,
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.neutral.container,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Column(
                  children: [
                    for (final entry in _labels.entries)
                      if (counts.containsKey(entry.key))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.value),
                              Text('${counts[entry.key]}'),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            AppSpacing.gap12,
            Text(
              widget.firstSetup
                  ? 'Your products, invoices, company details and the rest '
                        'of this backup will be restored on this device. The '
                        'app reopens when it is done.'
                  : 'This replaces ALL current data on this device with the '
                        'data in this backup. A safety copy of the current '
                        'data is saved first so you can go back.',
              style: theme.textTheme.bodyMedium,
            ),
            if (!widget.firstSetup) ...[
              AppSpacing.gap8,
              CheckboxListTile(
                key: const Key('backup-confirm-check'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _understood,
                onChanged: (value) =>
                    setState(() => _understood = value ?? false),
                title: const Text(
                  'I understand my current data will be replaced',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          key: const Key('backup-confirm-cancel'),
          label: 'Cancel',
          variant: AppButtonVariant.outlined,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          key: const Key('backup-confirm-restore'),
          label: 'Restore',
          variant: AppButtonVariant.destructive,
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
