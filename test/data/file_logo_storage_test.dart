import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/settings/data/repositories/file_logo_storage.dart';

import '../support/fakes.dart';

void main() {
  late Directory root;
  late FileLogoStorage storage;

  File makeFile(String name, {int bytes = 10}) =>
      File('${root.path}/$name')..writeAsBytesSync(List<int>.filled(bytes, 1));

  setUp(() {
    root = Directory.systemTemp.createTempSync('inventrix_logo_test_');
    storage = FileLogoStorage(
      ids: SequentialIds(),
      clock: FakeClock(),
      baseDirectory: () async => Directory('${root.path}/app')..createSync(),
    );
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('copies into the backed-up image folder with a logo_ name', () async {
    final result = await storage.store(makeFile('mark.PNG').path);
    final relative = result.valueOrNull!;
    expect(relative.startsWith('product_images/logo_'), isTrue);
    expect(relative.endsWith('.png'), isTrue);
    expect(File(await storage.resolvePath(relative)).existsSync(), isTrue);
    expect(await storage.read(relative), hasLength(10));
  });

  test('rejects other file types, missing files and oversized files', () async {
    expect(
      (await storage.store(makeFile('x.gif').path)).failureOrNull,
      isA<ValidationFailure>(),
    );
    expect(
      (await storage.store('${root.path}/none.png')).failureOrNull,
      isA<NotFoundFailure>(),
    );
    final big = makeFile('big.jpg', bytes: 5 * 1024 * 1024 + 1);
    expect(
      (await storage.store(big.path)).failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test('delete removes only logo files inside the image folder', () async {
    final relative = (await storage.store(makeFile('a.png').path)).valueOrNull!;
    final other = File('${root.path}/app/product_images/photo_1.jpg')
      ..createSync(recursive: true);
    await storage.delete(relative);
    await storage.delete('product_images/photo_1.jpg');
    await storage.delete('../outside.png');
    expect(File(await storage.resolvePath(relative)).existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    expect(await storage.read('product_images/photo_1.jpg'), isNull);
  });

  test('reading a missing logo gives null', () async {
    expect(await storage.read('product_images/logo_missing.png'), isNull);
  });
}
