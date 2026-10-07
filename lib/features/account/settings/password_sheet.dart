import 'package:flutter/material.dart';

/// A bottom sheet that collects a password and runs [onSubmit] with it. [onSubmit] returns null on success
/// (the sheet closes and the returned future completes with `true`) or the message to show inline (the sheet
/// stays open so the user can retype). The password lives only in the sheet's controller.
Future<bool> askForPassword(
  BuildContext context, {
  required String title,
  required String passwordLabel,
  required String confirmLabel,
  required String cancelLabel,
  required Future<String?> Function(String password) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PasswordSheet(
      title: title,
      passwordLabel: passwordLabel,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({
    required this.title,
    required this.passwordLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onSubmit,
  });
  final String title;
  final String passwordLabel;
  final String confirmLabel;
  final String cancelLabel;
  final Future<String?> Function(String password) onSubmit;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-sheet-field'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: widget.passwordLabel),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const Key('password-sheet-error'), style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text(widget.cancelLabel)),
              FilledButton(key: const Key('password-sheet-confirm'), onPressed: _busy ? null : _submit, child: Text(widget.confirmLabel)),
            ],
          ),
        ],
      ),
    );
  }
}
