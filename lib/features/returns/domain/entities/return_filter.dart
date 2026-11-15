import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Search criteria for the return list.
final class ReturnFilter extends Equatable {
  /// Creates a filter.
  const ReturnFilter({this.query = '', this.kind, this.invoiceId});

  /// Matches number, invoice number and party name.
  final String query;

  /// Only sales or only purchase returns; `null` lists both.
  final InvoiceKind? kind;

  /// Only returns of this invoice.
  final String? invoiceId;

  /// Copy with changes.
  ReturnFilter copyWith({
    String? query,
    InvoiceKind? kind,
    bool clearKind = false,
    String? invoiceId,
  }) => ReturnFilter(
    query: query ?? this.query,
    kind: clearKind ? null : (kind ?? this.kind),
    invoiceId: invoiceId ?? this.invoiceId,
  );

  @override
  List<Object?> get props => [query, kind, invoiceId];
}
