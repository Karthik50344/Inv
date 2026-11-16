import 'dart:io';

import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_journal_store.dart';
import 'package:inventrix/features/backup/domain/services/restore_journal_codec.dart';

/// [RestoreJournalStore] kept in `restore_journal.json` next to the data.
final class FileRestoreJournalStore implements RestoreJournalStore {
  /// Creates the store; [directory] resolves the folder that holds the file.
  FileRestoreJournalStore(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File(
    '${(await _directory()).path}${Platform.pathSeparator}restore_journal.json',
  );

  @override
  Future<RestoreJournalEntry?> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    return RestoreJournalCodec.tryDecode(await file.readAsString());
  }

  @override
  Future<void> write(RestoreJournalEntry entry) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(RestoreJournalCodec.encode(entry), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
