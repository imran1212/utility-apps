import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
          .clamp(0, 100).toDouble();
}

class ImageCompressionService {
  const ImageCompressionService();

  Future<CompressionResult> compressJpeg({
    required File source,
    required int quality,
  }) async {
    final safeQuality = quality.clamp(1, 100).toInt();
    final bytes = await FlutterImageCompress.compressWithFile(
      source.absolute.path,
      quality: safeQuality,
      format: CompressFormat.jpeg,
    );
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Image compression failed.');
    }
    return CompressionResult(
      bytes: bytes,
      originalBytes: await source.length(),
      quality: safeQuality,
    );
  }
}
