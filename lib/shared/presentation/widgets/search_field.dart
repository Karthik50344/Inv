import 'package:material_ui/material_ui.dart';
import 'package:inventrix/shared/presentation/widgets/app_search_field.dart';

/// Search box used by the list screens.
///
/// Kept for the existing screens; it is [AppSearchField] with the original
/// two-argument API. New code should use [AppSearchField] directly.
class SearchField extends StatelessWidget {
  /// Creates the field.
  const SearchField({
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  /// Placeholder text.
  final String hintText;

  /// Called on every edit with the current text.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) =>
      AppSearchField(hintText: hintText, onChanged: onChanged);
}
