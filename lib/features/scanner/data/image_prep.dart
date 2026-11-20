import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image sizes from PRD §11.
abstract final class ImageLimits {
  /// Sent to the AI: longest side 1024 px, ≤ 500 KB.
  static const int uploadMaxSide = 1024;
  static const int uploadMaxBytes = 500 * 1024;

  /// Kept on the device: longest side 512 px, about 80 KB.
  static const int thumbMaxSide = 512;
  static const int thumbTargetBytes = 80 * 1024;
}

class PreparedImage {
  const PreparedImage({required this.upload, required this.thumbnail});

  /// JPEG sent to `POST /analyze-food`.
  final Uint8List upload;

  /// JPEG stored locally as the food photo.
  final Uint8List thumbnail;
}

/// `flutter_image_compress` scales so that the *shorter* side reaches the
/// requested minimum. Returns the minimum that makes the *longer* side
/// [maxSide] (or keeps the size when the image is already small enough).
int shorterSideFor({
  required int width,
  required int height,
  required int maxSide,
}) {
  final longer = width > height ? width : height;
  final shorter = width > height ? height : width;
  if (longer <= maxSide) return shorter;
  return (shorter * maxSide / longer).floor();
}

/// Compresses a photo (in-app camera or gallery) before it is sent to the AI
/// proxy, and makes the local thumbnail.
class ImagePreparer {
  const ImagePreparer();

  Future<PreparedImage> prepare(String path) async {
    final (width, height) = await _dimensions(path);
    final upload = await _compress(
      path,
      shorterSideFor(
        width: width,
        height: height,
        maxSide: ImageLimits.uploadMaxSide,
      ),
      ImageLimits.uploadMaxBytes,
    );
    final thumb = await _compress(
      path,
      shorterSideFor(
        width: width,
        height: height,
        maxSide: ImageLimits.thumbMaxSide,
      ),
      ImageLimits.thumbTargetBytes,
    );
    return PreparedImage(upload: upload, thumbnail: thumb);
  }

  /// Reads only the image header.
  Future<(int, int)> _dimensions(String path) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await File(path).readAsBytes(),
    );
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = (descriptor.width, descriptor.height);
      descriptor.dispose();
      return size;
    } on Exception {
      throw const FormatException('This image could not be read.');
    } finally {
      buffer.dispose();
    }
  }

  Future<Uint8List> _compress(String path, int minSide, int maxBytes) async {
    Uint8List? best;
    for (final quality in const [85, 70, 55, 40]) {
      final out = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: minSide,
        minHeight: minSide,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (out == null) break;
      best = out;
      if (out.lengthInBytes <= maxBytes) return out;
    }
    if (best == null) {
      throw const FormatException('This image could not be read.');
    }
    return best;
  }
}
