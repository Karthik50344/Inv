import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/settings/domain/entities/numbering_settings.dart';
import 'package:inventrix/features/settings/domain/repositories/numbering_repository.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';

/// Prefixes and padding live in `app_settings`; counters in
/// `document_sequences` (written by posting, and moved forward here).
final class DriftNumberingRepository implements NumberingRepository {
  /// Creates the repository.
  const DriftNumberingRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<NumberingSettings>> load() => guardDatabase(() async {
    final settingRows = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.like('numbering.%'))).get();
    final values = {for (final row in settingRows) row.key: row.value};
    final prefixes = <DocumentKind, String>{};
    for (final kind in DocumentKind.values) {
      final stored = values[kind.prefixSettingKey];
      if (stored != null && DocumentNumber.validatePrefix(stored) == null) {
        prefixes[kind] = stored;
      }
    }
    final padding = int.tryParse(values[NumberingSettingKeys.padding] ?? '');
    final counters = await _db.select(_db.documentSequences).get();
    final byKey = {for (final row in counters) row.key: row.lastValue};
    return NumberingSettings(
      prefixes: prefixes,
      padding:
          padding != null && DocumentNumber.validatePadding(padding) == null
          ? padding
          : DocumentNumber.width,
      lastValues: {
        for (final kind in DocumentKind.values)
          if (byKey[kind.sequenceKey] != null) kind: byKey[kind.sequenceKey]!,
      },
    );
  });

  @override
  Future<Result<void>> save(NumberingSettings settings) =>
      guardDatabase(() async {
        final now = toEpochMs(DateTime.now());
        final entries = <String, String>{
          for (final kind in DocumentKind.values)
            kind.prefixSettingKey: settings.prefixOf(kind),
          NumberingSettingKeys.padding: '${settings.padding}',
        };
        await _db.transaction(() async {
          for (final entry in entries.entries) {
            await _db
                .into(_db.appSettings)
                .insertOnConflictUpdate(
                  AppSettingsCompanion(
                    key: Value(entry.key),
                    value: Value(entry.value),
                    updatedAt: Value(now),
                  ),
                );
          }
        });
      });

  @override
  Future<Result<void>> advanceTo(DocumentKind kind, int nextNumber) =>
      guardDatabase(() async {
        if (nextNumber < 1) {
          throw const FailureException(
            ValidationFailure('The next number must be at least 1.'),
          );
        }
        await _db.transaction(() async {
          final row = await (_db.select(
            _db.documentSequences,
          )..where((t) => t.key.equals(kind.sequenceKey))).getSingleOrNull();
          final last = row?.lastValue ?? 0;
          if (nextNumber - 1 < last) {
            throw FailureException(
              ValidationFailure(
                'Numbers up to $last are already used. '
                'Enter ${last + 1} or higher.',
              ),
            );
          }
          // MAX keeps the counter monotonic even if another writer got in.
          await _db.customStatement(
            'INSERT INTO document_sequences (key, last_value) VALUES (?, ?) '
            'ON CONFLICT(key) DO UPDATE SET '
            'last_value = MAX(last_value, excluded.last_value)',
            [kind.sequenceKey, nextNumber - 1],
          );
        });
      });
}
