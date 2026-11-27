import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Shows an image stored by `ImageStorage`, resolving its relative path
/// first. Falls back to [placeholder] when there is no image.
class StoredImage extends StatelessWidget {
  /// Creates the widget.
  const StoredImage({
    required this.relativePath,
    required this.resolvePath,
    required this.size,
    this.placeholder = const Icon(Icons.inventory_2_outlined),
    super.key,
  });

  /// Relative stored path, or `null` when there is no image.
  final String? relativePath;

  /// Resolves a relative path to an absolute file path.
  final Future<String> Function(String relativePath) resolvePath;

  /// Width and height.
  final double size;

  /// Shown when there is no (readable) image.
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    final path = relativePath;
    if (path == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: placeholder),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<String>(
        future: resolvePath(path),
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          if (resolved == null) {
            return Center(child: placeholder);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(resolved),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Center(child: placeholder),
            ),
          );
        },
      ),
    );
  }
}
