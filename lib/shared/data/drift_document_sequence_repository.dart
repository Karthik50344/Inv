import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';

/// Drift implementation of [DocumentSequenceRepository].
///
/// The upsert and the read happen on the caller's transaction, so the
/// counter only advances when the document that uses the number commits.
final class DriftDocumentSequenceRepository
    implements DocumentSequenceRepository {
  /// Creates the repository.
  const DriftDocumentSequenceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<int>> next(String key) => guardDatabase(() async {
    await _db.customStatement(
      'INSERT INTO document_sequences (key, last_value) VALUES (?, 1) '
      'ON CONFLICT(key) DO UPDATE SET last_value = last_value + 1',
      [key],
    );
    final row = await _db
        .customSelect(
          'SELECT last_value FROM document_sequences WHERE key = ?',
          variables: [Variable.withString(key)],
          readsFrom: {_db.documentSequences},
        )
        .getSingle();
    return row.read<int>('last_value');
  });

  @override
  Future<Result<String>> nextNumber(DocumentKind kind) =>
      guardDatabase(() async {
        final sequence = (await next(kind.sequenceKey)).getOrThrow();
        final rows =
            await (_db.select(_db.appSettings)..where(
                  (t) => t.key.isIn([
                    kind.prefixSettingKey,
                    NumberingSettingKeys.padding,
                  ]),
                ))
                .get();
        final values = {for (final row in rows) row.key: row.value};
        final storedPrefix = values[kind.prefixSettingKey];
        final prefix =
            storedPrefix != null &&
                DocumentNumber.validatePrefix(storedPrefix) == null
            ? storedPrefix
            : kind.defaultPrefix;
        final storedPadding = int.tryParse(
          values[NumberingSettingKeys.padding] ?? '',
        );
        final padding =
            storedPadding != null &&
                DocumentNumber.validatePadding(storedPadding) == null
            ? storedPadding
            : DocumentNumber.width;
        return DocumentNumber.format(prefix, sequence, padding: padding);
      });
}
