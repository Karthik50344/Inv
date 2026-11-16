import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/backup/data/services/zip_backup_packager.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';

import '../../support/backup_fakes.dart';

void main() {
  late TestStorage storage;
  late ZipBackupPackager packager;
  late Directory work;

  setUp(() async {
    storage = await TestStorage.create();
    packager = ZipBackupPackager();
    work = Directory('${storage.root.path}/work')..createSync();
    Directory('${storage.docs.path}/attachments').createSync();
    File('${storage.docs.path}/attachments/r1.pdf')
        .writeAsStringSync('receipt');
    Directory('${storage.docs.path}/product_images').createSync();
    Directory('${storage.docs.path}/product_images/sub').createSync();
    File('${storage.docs.path}/product_images/sub/p.png')
        .writeAsStringSync('png');
  });
  tearDown(() => storage.dispose());

  Future<PackedBackup> pack() async {
    final result = await packager.pack(
      PackRequest(
        databasePath: storage.database.path,
        dataFolders: await storage.locations.dataFolders(),
        outputPath: '${work.path}/b.zip',
        createdAt: DateTime.utc(2026, 11, 15),
        appVersion: '1.0.0',
        schemaVersion: 9,
      ),
    );
    return result.valueOrNull!;
  }

  Future<String> staging() async {
    final d = await Directory('${work.path}/stage').create();
    for (final e in d.listSync()) {
      e.deleteSync(recursive: true);
    }
    return d.path;
  }

  String zipOf(List<ArchiveFile> files, String name) {
    final archive = Archive();
    for (final f in files) {
      archive.add(f);
    }
    final path = '${work.path}/$name';
    File(path).writeAsBytesSync(ZipEncoder().encode(archive));
    return path;
  }

  test('pack then verify then unpack round-trips every file', () async {
    final packed = await pack();
    expect(packed.sha256.length, 64);
    expect(packed.manifest.attachments.length, 2);
    expect(File('${work.path}/b.zip.part').existsSync(), isFalse);

    expect((await packager.verify(packed.path)).isSuccess, isTrue);
    final staged = (await packager.unpack(
      archivePath: packed.path,
      stagingDirectory: await staging(),
    )).valueOrNull!;
    expect(File(staged.databasePath).readAsStringSync(), 'live-data');
    expect(
      File('${staged.dataFolders[BackupDataFolders.receipts]}/r1.pdf')
          .readAsStringSync(),
      'receipt',
    );
    expect(
      File('${staged.dataFolders[BackupDataFolders.productImages]}/sub/p.png')
          .existsSync(),
      isTrue,
    );
    expect(staged.archiveSha256, packed.sha256);
  });

  test('a flipped byte inside a stored file is detected', () async {
    final packed = await pack();
    final archive = ZipDecoder().decodeBytes(
      File(packed.path).readAsBytesSync(),
    );
    final rebuilt = Archive();
    for (final f in archive) {
      if (f.name == BackupFormat.databasePath) {
        rebuilt.add(ArchiveFile.string(f.name, 'tampered!!'));
      } else {
        rebuilt.add(ArchiveFile.bytes(f.name, f.readBytes()!));
      }
    }
    final bad = '${work.path}/tampered.zip';
    File(bad).writeAsBytesSync(ZipEncoder().encode(rebuilt));
    final result = await packager.unpack(
      archivePath: bad,
      stagingDirectory: await staging(),
    );
    expect(result.failureOrNull, isA<RestoreFailure>());
    expect(Directory(await staging()).listSync(), isEmpty);
  });

  test('path traversal entries are refused and nothing is written', () async {
    final path = zipOf([ArchiveFile.string('../../evil.txt', 'x')], 'slip.zip');
    final result = await packager.unpack(
      archivePath: path,
      stagingDirectory: await staging(),
    );
    expect(result.failureOrNull, isA<RestoreFailure>());
    expect(File('${storage.root.path}/evil.txt').existsSync(), isFalse);
    expect(File('${work.path}/../evil.txt').existsSync(), isFalse);
  });

  test('unknown entries, absolute paths and backslashes are refused', () async {
    for (final name in [
      '/etc/passwd',
      'database\\x.sqlite',
      'other/file.txt',
      'C:/x',
    ]) {
      final path = zipOf([ArchiveFile.string(name, 'x')], 'bad.zip');
      final result = await packager.unpack(
        archivePath: path,
        stagingDirectory: await staging(),
      );
      expect(result.isFailure, isTrue, reason: name);
    }
  });

  test('an entry missing from the manifest is refused', () async {
    final packed = await pack();
    final archive = ZipDecoder().decodeBytes(
      File(packed.path).readAsBytesSync(),
    );
    final rebuilt = Archive();
    for (final f in archive) {
      rebuilt.add(ArchiveFile.bytes(f.name, f.readBytes()!));
    }
    rebuilt.add(ArchiveFile.string('attachments/receipts/extra.pdf', 'sneaky'));
    final bad = '${work.path}/extra.zip';
    File(bad).writeAsBytesSync(ZipEncoder().encode(rebuilt));
    final result = await packager.unpack(
      archivePath: bad,
      stagingDirectory: await staging(),
    );
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull!.message, contains('not in its manifest'));
  });

  test('a non-zip file and a missing file fail cleanly', () async {
    File('${work.path}/x.zip').writeAsStringSync('not a zip');
    expect(
      (await packager.unpack(
        archivePath: '${work.path}/x.zip',
        stagingDirectory: await staging(),
      )).failureOrNull,
      isA<RestoreFailure>(),
    );
    expect(
      (await packager.unpack(
        archivePath: '${work.path}/none.zip',
        stagingDirectory: await staging(),
      )).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('a manifest from another application is refused', () async {
    final path = zipOf([
      ArchiveFile.string('manifest.json', '{"application":"other"}'),
    ], 'other.zip');
    final result = await packager.unpack(
      archivePath: path,
      stagingDirectory: await staging(),
    );
    expect(result.failureOrNull!.message, contains('not an Inventrix backup'));
  });

  test('a non-empty staging folder is rejected', () async {
    final packed = await pack();
    final s = await staging();
    File('$s/leftover').writeAsStringSync('x');
    final result = await packager.unpack(
      archivePath: packed.path,
      stagingDirectory: s,
    );
    expect(result.isFailure, isTrue);
  });

  test(
    'a missing folder is skipped and the database alone is a valid backup',
    () async {
      Directory('${storage.docs.path}/attachments').deleteSync(recursive: true);
      Directory('${storage.docs.path}/product_images')
          .deleteSync(recursive: true);
      final packed = await pack();
      expect(packed.manifest.attachments, isEmpty);
      expect((await packager.verify(packed.path)).isSuccess, isTrue);
    },
  );
}
