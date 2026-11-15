import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';

/// Search input used above lists.
class SearchField extends StatelessWidget {
  /// Creates a search field.
  const SearchField({
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  /// Placeholder text.
  final String hintText;

  /// Called whenever the text changes.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spaceMd,
        AppDimensions.spaceSm,
        AppDimensions.spaceMd,
        AppDimensions.spaceSm,
      ),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
