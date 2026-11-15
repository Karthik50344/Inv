import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/data/repositories/file_image_storage.dart';

import '../support/fakes.dart';

void main() {
  late Directory root;
  late FileImageStorage storage;

  File makeFile(String name, {int bytes = 10}) {
    final file = File('${root.path}/$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 1));
    return file;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('inventrix_img_test_');
    storage = FileImageStorage(
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

  test('copies the image and returns a relative path', () async {
    final source = makeFile('photo.JPG');
    final result = await storage.storeProductImage(source.path);
    final relative = result.valueOrNull!;
    expect(relative.startsWith('product_images/'), isTrue);
    expect(relative.endsWith('.jpg'), isTrue);
    final absolute = await storage.resolvePath(relative);
    expect(File(absolute).existsSync(), isTrue);
    expect(source.existsSync(), isTrue);
  });

  test('stored paths are independent of the base directory', () async {
    final result = await storage.storeProductImage(makeFile('a.png').path);
    expect(result.valueOrNull!.contains(root.path), isFalse);
  });

  test('rejects unsupported file types', () async {
    final result = await storage.storeProductImage(makeFile('notes.txt').path);
    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('rejects missing files', () async {
    final result = await storage.storeProductImage('${root.path}/missing.png');
    expect(result.failureOrNull, isA<NotFoundFailure>());
  });

  test('rejects files over 10 MB', () async {
    final big = makeFile('big.png', bytes: 10 * 1024 * 1024 + 1);
    final result = await storage.storeProductImage(big.path);
    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('two images get different names', () async {
    final a = await storage.storeProductImage(makeFile('a.png').path);
    final b = await storage.storeProductImage(makeFile('b.png').path);
    expect(a.valueOrNull, isNot(b.valueOrNull));
  });
}
