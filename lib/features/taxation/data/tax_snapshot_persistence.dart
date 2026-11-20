import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/taxation/domain/entities/line_tax_snapshot.dart';

/// Writes and clears the per-component tax rows that sit next to a document
/// line. Used by the sales and purchase repositories inside their draft-save
/// transaction; the rows become immutable with the document (database
/// triggers).
abstract final class TaxSnapshotPersistence {
  /// Removes the component rows of every line of [invoiceId]. Call it
  /// before the draft's lines are deleted.
  static Future<void> clearForInvoice(
    AppDatabase db, {
    required String documentType,
    required String invoiceId,
  }) {
    final items = documentType == 'sales'
        ? 'sales_invoice_items'
        : 'purchase_invoice_items';
    return db.customStatement(
      'DELETE FROM invoice_item_tax_components WHERE document_type = ? '
      'AND item_id IN (SELECT id FROM $items WHERE invoice_id = ?)',
      [documentType, invoiceId],
    );
  }

  /// Inserts one row per component of [snapshot] for line [itemId].
  static Future<void> insertForLine(
    AppDatabase db, {
    required String documentType,
    required String itemId,
    required LineTaxSnapshot? snapshot,
  }) async {
    if (snapshot == null) {
      return;
    }
    for (final c in snapshot.components) {
      await db
          .into(db.invoiceItemTaxComponents)
          .insert(
            InvoiceItemTaxComponentsCompanion(
              id: Value('$itemId:${c.order}'),
              documentType: Value(documentType),
              itemId: Value(itemId),
              componentNo: Value(c.order),
              ruleId: Value(c.ruleId),
              componentId: Value(c.componentId),
              name: Value(c.name),
              componentType: Value(c.type),
              calculationMethod: Value(c.method),
              rateBasisPoints: Value(c.rateBasisPoints),
              fixedAmountMinor: Value(c.fixedAmountMinor),
              taxableMinor: Value(c.taxableMinor),
              amountMinor: Value(c.amountMinor),
              isCompound: Value(c.isCompound),
              isRecoverable: Value(c.isRecoverable),
            ),
          );
    }
  }
}
