import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';

/// Shows what a backup contains and asks for explicit confirmation before
/// the current data is replaced. Resolves to `true` only when confirmed.
Future<bool> showRestoreConfirmationDialog(
  BuildContext context,
  BackupPreview preview,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RestoreDialog(preview: preview),
  );
  return confirmed ?? false;
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.preview});

  final BackupPreview preview;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  bool _understood = false;

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
    final manifest = widget.preview.staged.manifest;
    final counts = widget.preview.inspection.recordCounts;
    final created = DateFormat.yMMMd().add_Hm().format(
      manifest.createdAt.toLocal(),
    );
    return AlertDialog(
      title: const Text('Replace your data?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.preview.staged.sourceName,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text('Created $created · app ${manifest.appVersion}'),
            const SizedBox(height: 12),
            for (final entry in _labels.entries)
              if (counts.containsKey(entry.key))
                Text('${entry.value}: ${counts[entry.key]}'),
            const SizedBox(height: 12),
            Text(
              'This replaces ALL current data on this device with the data '
              'in this backup. A safety copy of the current data is saved '
              'first so you can go back.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
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
        ),
      ),
      actions: [
        TextButton(
          key: const Key('backup-confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('backup-confirm-restore'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Restore'),
        ),
      ],
    );
  }
}
