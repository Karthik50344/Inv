import 'package:flutter/material.dart';

/// Asks why a document is being voided. Returns the entered reason, or
/// `null` when the user keeps the document.
///
/// The text controller belongs to the dialog's own [State], so it is
/// disposed only after the dialog route has finished closing (disposing it
/// right when `showDialog` completes would use it during the exit
/// animation).
Future<String?> askVoidReason(
  BuildContext context, {
  required String title,
}) => showDialog<String>(
  context: context,
  builder: (_) => _VoidReasonDialog(title: title),
);

class _VoidReasonDialog extends StatefulWidget {
  const _VoidReasonDialog({required this.title});

  final String title;

  @override
  State<_VoidReasonDialog> createState() => _VoidReasonDialogState();
}

class _VoidReasonDialogState extends State<_VoidReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const Key('void_reason_input'),
      controller: _controller,
      autofocus: true,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Reason *',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Keep'),
      ),
      FilledButton(
        key: const Key('confirm_void'),
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Void'),
      ),
    ],
  );
}
