/// Inserts [separator] into a string of plain digits.
///
/// Works on text, never on `double`, so any size of number is exact.
/// With [indian] set the last three digits form one group and every group
/// before that has two (`1234567` -> `12,34,567`); otherwise groups have
/// three digits (`1,234,567`).
String groupDigits(
  String digits, {
  required String separator,
  required bool indian,
}) {
  if (digits.length <= 3) {
    return digits;
  }
  final groups = <String>[];
  var end = digits.length;
  var size = 3;
  while (end > 0) {
    final start = end - size < 0 ? 0 : end - size;
    groups.insert(0, digits.substring(start, end));
    end = start;
    if (indian) {
      size = 2;
    }
  }
  return groups.join(separator);
}
