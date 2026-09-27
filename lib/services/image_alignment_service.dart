import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Service responsible for manipulating, rotating, and preparing timetable images
/// for direct sharing with AI assistants.
class ImageAlignmentService {
  /// Rotates the given [imageBytes] by [quarterTurns] * 90 degrees clockwise.
  /// If [quarterTurns] % 4 == 0, returns the original [imageBytes] unchanged.
  static Future<Uint8List> rotateImage(Uint8List imageBytes, int quarterTurns) async {
    final turns = quarterTurns % 4;
    if (turns == 0) return imageBytes;

    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final srcImage = frameInfo.image;

      final isSwapped = turns == 1 || turns == 3;
      final destWidth = (isSwapped ? srcImage.height : srcImage.width).toDouble();
      final destHeight = (isSwapped ? srcImage.width : srcImage.height).toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.save();
      if (turns == 1) {
        // 90 degrees clockwise
        canvas.translate(destWidth, 0);
        canvas.rotate(math.pi / 2);
      } else if (turns == 2) {
        // 180 degrees
        canvas.translate(destWidth, destHeight);
        canvas.rotate(math.pi);
      } else if (turns == 3) {
        // 270 degrees clockwise (90 counter-clockwise)
        canvas.translate(0, destHeight);
        canvas.rotate(3 * math.pi / 2);
      }
      canvas.drawImage(srcImage, Offset.zero, Paint());
      canvas.restore();

      final picture = recorder.endRecording();
      final rotatedImage = await picture.toImage(destWidth.toInt(), destHeight.toInt());
      final byteData = await rotatedImage.toByteData(format: ui.ImageByteFormat.png);

      srcImage.dispose();
      rotatedImage.dispose();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      return imageBytes;
    } catch (_) {
      // Graceful fallback to original bytes on error
      return imageBytes;
    }
  }

  /// Prepares an image for sharing by applying any rotation and saving it
  /// to a temporary file accessible to system intents.
  static Future<String> prepareImageForShare({
    required Uint8List bytes,
    required int quarterTurns,
    String? originalPath,
  }) async {
    final turns = quarterTurns % 4;

    // If no rotation was applied and original file exists, use it directly
    if (turns == 0 && originalPath != null && originalPath.isNotEmpty) {
      final origFile = File(originalPath);
      if (origFile.existsSync()) {
        return origFile.path;
      }
    }

    // Apply rotation if needed
    final processedBytes = turns != 0 ? await rotateImage(bytes, turns) : bytes;

    // Save to temp directory for sharing
    final tempDir = Directory.systemTemp;
    final shareDir = Directory('${tempDir.path}/jadwal_shared');
    if (!shareDir.existsSync()) {
      shareDir.createSync(recursive: true);
    } else {
      // Clean up older shared images to prevent storage buildup
      try {
        final existingFiles = shareDir.listSync().whereType<File>().toList();
        if (existingFiles.length > 5) {
          existingFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
          for (int i = 0; i < existingFiles.length - 3; i++) {
            existingFiles[i].deleteSync();
          }
        }
      } catch (_) {}
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${shareDir.path}/timetable_$timestamp.png');
    file.writeAsBytesSync(processedBytes);
    return file.path;
  }
}
