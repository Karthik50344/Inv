final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _phonePattern = RegExp(r'^[0-9+\-()\s]+$');

/// Trims [value]; returns `null` when it is null or blank.
String? blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Reusable field validators. Each returns an error message or `null`.
abstract final class Validators {
  /// Required text with a maximum length.
  static String? requiredText(
    String? value, {
    required String label,
    int maxLength = 120,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '$label is required.';
    }
    if (text.length > maxLength) {
      return '$label must be at most $maxLength characters.';
    }
    return null;
  }

  /// Optional text with a maximum length.
  static String? optionalText(
    String? value, {
    required String label,
    int maxLength = 500,
  }) {
    final text = value?.trim() ?? '';
    if (text.length > maxLength) {
      return '$label must be at most $maxLength characters.';
    }
    return null;
  }

  /// Optional e-mail address.
  static String? optionalEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    if (text.length > 254 || !_emailPattern.hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Optional phone number (digits, spaces, + - and parentheses).
  static String? optionalPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (!_phonePattern.hasMatch(text) || digits < 6 || digits > 15) {
      return 'Enter a valid phone number.';
    }
    return null;
  }
}
