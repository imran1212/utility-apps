import 'dart:io';

import 'package:flutter/services.dart';

class CompressionResult {
  const CompressionResult({
    required this.bytes,
    required this.originalBytes,
    required this.quality,
  });

  final List<int> bytes;
  final int originalBytes;
  final int quality;

  int get compressedBytes => bytes.length;

  double get savedPercent => originalBytes == 0
      ? 0
      : ((originalBytes - compressedBytes) / originalBytes * 100)
          .clamp(0, 100)
          .toDouble();
}

/// Android compression engine backed by zetbaitsu/Compressor (Apache-2.0).
///
/// The native library performs work off the UI thread, applies EXIF rotation,
/// and supports resolution, quality, output-format and target-size constraints.
class ImageCompressionService {
  const ImageCompressionService();

  static const MethodChannel _channel =
      MethodChannel('svsystem/image_compressor');

  Future<CompressionResult> compressJpeg({
    required File source,
    required int quality,
    int? maxWidth,
    int? maxHeight,
    int? targetBytes,
  }) async {
    if (!await source.exists()) {
      throw const FileSystemException('The source image does not exist.');
    }

    final originalBytes = await source.length();
    if (originalBytes <= 0) {
      throw const FileSystemException('The source image is empty.');
    }

    final safeQuality = quality.clamp(10, 100).toInt();
    final outputPath = await _channel.invokeMethod<String>(
      'compress',
      <String, Object>{
        'sourcePath': source.absolute.path,
        'quality': safeQuality,
        'maxWidth': (maxWidth ?? 4096).clamp(1, 8192),
        'maxHeight': (maxHeight ?? 4096).clamp(1, 8192),
        'targetBytes': targetBytes == null
            ? originalBytes - 1
            : targetBytes.clamp(1024, 100 * 1024 * 1024),
      },
    );

    if (outputPath == null || outputPath.isEmpty) {
      throw StateError('The Android compressor returned no output file.');
    }

    final output = File(outputPath);
    try {
      if (!await output.exists()) {
        throw StateError('The compressed image file was not created.');
      }
      final bytes = await output.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('The compressed image is empty.');
      }
      return CompressionResult(
        bytes: bytes,
        originalBytes: originalBytes,
        quality: safeQuality,
      );
    } finally {
      if (await output.exists()) {
        await output.delete();
      }
    }
  }
}
