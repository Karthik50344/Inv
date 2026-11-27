import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';

/// Asks for an optional recovery passphrase before a backup is created.
///
/// Resolves to `null` if cancelled, `''` for "no passphrase" and otherwise
/// the passphrase.
Future<String?> showCreateBackupDialog(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _CreateDialog(),
);

/// Asks for the recovery passphrase of a backup from another device.
/// Resolves to `null` if cancelled.
Future<String?> showRestorePassphraseDialog(
  BuildContext context, {
  bool incorrect = false,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _RestoreDialog(incorrect: incorrect),
);

class _CreateDialog extends StatefulWidget {
  const _CreateDialog();

  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _pass.text;
    if (text.isNotEmpty) {
      if (text.length < CreateBackup.minPassphraseLength) {
        setState(
          () => _error =
              'Use at least ${CreateBackup.minPassphraseLength} characters.',
        );
        return;
      }
      if (text != _confirm.text) {
        setState(() => _error = 'The two passphrases are different.');
        return;
      }
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Protect this backup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backups are always encrypted. Without a recovery passphrase '
              'only this installation of the app can open the backup: after '
              'a reinstall or on a new phone it cannot be restored.\n\n'
              'Set a recovery passphrase to restore it anywhere. There is no '
              'way to recover a forgotten passphrase.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('backup-passphrase'),
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Recovery passphrase (optional)',
              ),
            ),
            TextField(
              key: const Key('backup-passphrase-confirm'),
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Repeat passphrase',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('backup-passphrase-submit'),
          onPressed: _submit,
          child: const Text('Create backup'),
        ),
      ],
    );
  }
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({required this.incorrect});

  final bool incorrect;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _pass = TextEditingController();

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recovery passphrase'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This backup was made on another device or installation. Enter '
            'the recovery passphrase that was set when it was created.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('restore-passphrase'),
            controller: _pass,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Recovery passphrase',
              errorText: widget.incorrect
                  ? 'That passphrase is not correct.'
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('restore-passphrase-submit'),
          onPressed: () => Navigator.of(context).pop(_pass.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// Listener that asks for the recovery passphrase whenever the bloc says a
/// backup needs one, and sends the answer back. Add it to the page's
/// `MultiBlocListener`.
BlocListener<BackupBloc, BackupState> backupPassphraseListener() =>
    BlocListener<BackupBloc, BackupState>(
      listenWhen: (a, b) =>
          a.passphrasePrompt != b.passphrasePrompt &&
          b.passphrasePrompt != null,
      listener: (context, state) async {
        final bloc = context.read<BackupBloc>();
        final prompt = state.passphrasePrompt!;
        final entered = await showRestorePassphraseDialog(
          context,
          incorrect: prompt.incorrect,
        );
        bloc.add(
          entered == null || entered.isEmpty
              ? const BackupPassphraseCancelled()
              : BackupFileSelected(prompt.path, passphrase: entered),
        );
      },
    );
