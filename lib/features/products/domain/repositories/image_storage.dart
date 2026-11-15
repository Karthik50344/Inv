import 'package:inventrix/core/result/result.dart';

/// Stores product images inside the app's private storage.
///
/// Stored paths are **relative** (e.g. `product_images/abc.jpg`) because the
/// absolute application directory can change between app updates on iOS.
abstract interface class ImageStorage {
  /// Copies the picked file at [sourcePath] into app storage and returns the
  /// relative stored path. Fails with `ValidationFailure` for unsupported or
  /// oversized files.
  Future<Result<String>> storeProductImage(String sourcePath);

  /// Resolves a stored relative path to an absolute file path for display.
  Future<String> resolvePath(String relativePath);
}
