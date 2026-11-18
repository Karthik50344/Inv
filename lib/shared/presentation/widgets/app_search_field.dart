import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_spacing.dart';

/// Search box with a clear button and an optional trailing slot (for
/// example an `AppFilterButton`).
class AppSearchField extends StatefulWidget {
  /// Creates a search field.
  const AppSearchField({
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
    this.controller,
    this.trailing,
    this.autofocus = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.s16,
      AppSpacing.s8,
      AppSpacing.s16,
      AppSpacing.s8,
    ),
    super.key,
  });

  /// Placeholder.
  final String hintText;

  /// Called on every edit.
  final ValueChanged<String> onChanged;

  /// Called when the search key is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Optional external controller.
  final TextEditingController? controller;

  /// Widget shown to the right of the field.
  final Widget? trailing;

  /// Focuses the field when it first appears.
  final bool autofocus;

  /// Space around the whole row.
  final EdgeInsetsGeometry padding;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_refresh);
      _controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _own?.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: _clear,
              ),
      ),
    );
    return Padding(
      padding: widget.padding,
      child: widget.trailing == null
          ? field
          : Row(
              children: [
                Expanded(child: field),
                AppSpacing.hGap8,
                widget.trailing!,
              ],
            ),
    );
  }
}
