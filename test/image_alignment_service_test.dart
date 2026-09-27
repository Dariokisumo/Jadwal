import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:jadwal/services/image_alignment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Minimal 1x1 valid PNG bytes
  final kMinimalPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  group('ImageAlignmentService', () {
    test('returns original bytes when quarterTurns is 0 or multiple of 4', () async {
      final res0 = await ImageAlignmentService.rotateImage(kMinimalPng, 0);
      expect(res0, equals(kMinimalPng));

      final res4 = await ImageAlignmentService.rotateImage(kMinimalPng, 4);
      expect(res4, equals(kMinimalPng));
    });

    test('rotates image bytes for quarterTurns 1, 2, 3', () async {
      final res1 = await ImageAlignmentService.rotateImage(kMinimalPng, 1);
      expect(res1.isNotEmpty, isTrue);

      final res2 = await ImageAlignmentService.rotateImage(kMinimalPng, 2);
      expect(res2.isNotEmpty, isTrue);

      final res3 = await ImageAlignmentService.rotateImage(kMinimalPng, 3);
      expect(res3.isNotEmpty, isTrue);
    });

    test('prepareImageForShare uses originalPath if quarterTurns is 0', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_orig.png');
      await tempFile.writeAsBytes(kMinimalPng);

      final path = await ImageAlignmentService.prepareImageForShare(
        bytes: kMinimalPng,
        quarterTurns: 0,
        originalPath: tempFile.path,
      );

      expect(path, equals(tempFile.path));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('prepareImageForShare creates a rotated file when quarterTurns > 0', () async {
      final path = await ImageAlignmentService.prepareImageForShare(
        bytes: kMinimalPng,
        quarterTurns: 1,
      );

      expect(path.endsWith('.png'), isTrue);
      final file = File(path);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      await file.delete();
    });
  });
}
