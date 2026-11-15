import 'package:inventrix/core/utils/rounding.dart';

final RegExp _decimalPattern = RegExp(r'^([+-])?(\d*)(?:\.(\d*))?$');

/// Parses plain decimal text (no grouping separators, no exponent) into an
/// integer scaled by 10^[scale], without using floating point.
///
/// Returns `null` if the text is malformed, has more than
/// [maxFractionDigits] significant fraction digits (default: [scale]) or does
/// not fit in 64 bits. Trailing zeros in the fraction are ignored.
int? parseScaledDecimal(
  String input, {
  required int scale,
  int? maxFractionDigits,
}) {
  final maxFraction = maxFractionDigits ?? scale;
  if (scale < 0 || maxFraction < 0 || maxFraction > scale) {
    throw ArgumentError('Invalid scale/maxFractionDigits');
  }
  final match = _decimalPattern.firstMatch(input.trim());
  if (match == null) {
    return null;
  }
  final sign = match.group(1);
  final whole = match.group(2) ?? '';
  final fraction = (match.group(3) ?? '').replaceFirst(RegExp(r'0+$'), '');
  if (whole.isEmpty && (match.group(3) ?? '').isEmpty) {
    return null;
  }
  if (fraction.length > maxFraction) {
    return null;
  }
  final digits = BigInt.parse(
    '${whole.isEmpty ? '0' : whole}${fraction.padRight(scale, '0')}',
  );
  final signed = sign == '-' ? -digits : digits;
  return signed.isValidInt ? signed.toInt() : null;
}

/// Formats an integer scaled by 10^[scale] as plain decimal text.
///
/// [fractionDigits] defaults to [scale]; a smaller value rounds half away
/// from zero, a larger value pads with zeros.
String formatScaledDecimal(
  int value, {
  required int scale,
  int? fractionDigits,
}) {
  final digits = fractionDigits ?? scale;
  if (scale < 0 || digits < 0) {
    throw ArgumentError('scale and fractionDigits must not be negative');
  }
  var scaled = value;
  var currentScale = scale;
  if (digits < scale) {
    scaled = divideRounded(value, pow10(scale - digits));
    currentScale = digits;
  } else if (digits > scale) {
    scaled = roundedMulDiv(value, pow10(digits - scale), 1);
    currentScale = digits;
  }
  final negative = scaled < 0;
  final absolute = BigInt.from(scaled).abs().toString();
  final sign = negative ? '-' : '';
  if (currentScale == 0) {
    return '$sign$absolute';
  }
  final padded = absolute.padLeft(currentScale + 1, '0');
  final cut = padded.length - currentScale;
  return '$sign${padded.substring(0, cut)}.${padded.substring(cut)}';
}
