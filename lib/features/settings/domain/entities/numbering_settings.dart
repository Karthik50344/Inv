import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';

/// Prefixes and padding of document numbers, with the counters reached so
/// far (read-only here: counters only ever move forward).
final class NumberingSettings extends Equatable {
  /// Creates settings. Kinds missing from [prefixes] use their default
  /// prefix; kinds missing from [lastValues] have not issued a number yet.
  const NumberingSettings({
    this.prefixes = const {},
    this.padding = DocumentNumber.width,
    this.lastValues = const {},
  });

  /// Chosen prefixes.
  final Map<DocumentKind, String> prefixes;

  /// Digits the counter is padded to.
  final int padding;

  /// Last number issued per kind (`0` or missing = none yet).
  final Map<DocumentKind, int> lastValues;

  /// Prefix of [kind].
  String prefixOf(DocumentKind kind) => prefixes[kind] ?? kind.defaultPrefix;

  /// Last number issued for [kind].
  int lastValueOf(DocumentKind kind) => lastValues[kind] ?? 0;

  /// Number the next document of [kind] will get.
  int nextValueOf(DocumentKind kind) => lastValueOf(kind) + 1;

  /// The next number as it will be printed, e.g. `INV-000042`.
  String preview(DocumentKind kind) => DocumentNumber.format(
    prefixOf(kind),
    nextValueOf(kind),
    padding: padding,
  );

  /// Copy with new prefixes and/or padding (counters are not editable here).
  NumberingSettings copyWith({
    Map<DocumentKind, String>? prefixes,
    int? padding,
  }) => NumberingSettings(
    prefixes: prefixes ?? this.prefixes,
    padding: padding ?? this.padding,
    lastValues: lastValues,
  );

  @override
  List<Object?> get props => [prefixes, padding, lastValues];
}
