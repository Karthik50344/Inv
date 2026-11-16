import 'dart:convert';

import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';

/// JSON form of [RestoreJournalEntry].
abstract final class RestoreJournalCodec {
  /// Serialises [entry].
  static String encode(RestoreJournalEntry entry) =>
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'id': entry.id,
        'state': entry.state.value,
        'startedAt': entry.startedAt.toUtc().toIso8601String(),
        'sourceName': entry.sourceName,
        'restoredSchemaVersion': entry.restoredSchemaVersion,
        'failureMessage': entry.failureMessage,
        'databasePath': entry.targets.databasePath,
        'dataFolders': {
          for (final folder in entry.targets.dataFolders)
            folder.zipName: folder.directoryPath,
        },
        'safetyBackup': _recordToJson(entry.safetyBackup),
      });

  /// Parses [source]; returns `null` when it is damaged or unknown.
  static RestoreJournalEntry? tryDecode(String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, Object?>) {
        return null;
      }
      final state = RestoreJournalState.tryParse(json['state']! as String);
      final folders = json['dataFolders']! as Map<String, Object?>;
      final started = DateTime.parse(json['startedAt']! as String);
      if (state == null) {
        return null;
      }
      return RestoreJournalEntry(
        id: json['id']! as String,
        state: state,
        startedAt: started.toUtc(),
        sourceName: json['sourceName']! as String,
        restoredSchemaVersion: json['restoredSchemaVersion']! as int,
        failureMessage: json['failureMessage'] as String?,
        targets: RestoreTargets(
          databasePath: json['databasePath']! as String,
          dataFolders: [
            for (final entry in folders.entries)
              BackupDataFolder(
                zipName: entry.key,
                directoryPath: entry.value! as String,
              ),
          ],
        ),
        safetyBackup: _recordFromJson(
          json['safetyBackup']! as Map<String, Object?>,
        ),
      );
    } on Object {
      return null;
    }
  }

  static Map<String, Object?> _recordToJson(BackupRecord record) => {
    'id': record.id,
    'kind': record.kind.value,
    'fileName': record.fileName,
    'storedPath': record.storedPath,
    'sizeBytes': record.sizeBytes,
    'sha256': record.sha256,
    'schemaVersion': record.schemaVersion,
    'appVersion': record.appVersion,
    'outcome': record.outcome.value,
    'errorMessage': record.errorMessage,
    'createdAt': record.createdAt.toUtc().toIso8601String(),
  };

  static BackupRecord _recordFromJson(Map<String, Object?> json) =>
      BackupRecord(
        id: json['id']! as String,
        kind: BackupKind.fromValue(json['kind']! as String),
        fileName: json['fileName']! as String,
        storedPath: json['storedPath'] as String?,
        sizeBytes: json['sizeBytes']! as int,
        sha256: json['sha256'] as String?,
        schemaVersion: json['schemaVersion']! as int,
        appVersion: json['appVersion']! as String,
        outcome: BackupOutcome.fromValue(json['outcome']! as String),
        errorMessage: json['errorMessage'] as String?,
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
      );
}
