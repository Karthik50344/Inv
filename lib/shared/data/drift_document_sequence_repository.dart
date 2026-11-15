import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
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
}
