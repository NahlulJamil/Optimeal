import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image sizes from PRD §11.
abstract final class ImageLimits {
  /// Sent to the AI: max 1024 px, ≤ 500 KB.
  static const int uploadMaxSide = 1024;
  static const int uploadMaxBytes = 500 * 1024;

  /// Kept on the device: about 512 px, about 80 KB. `flutter_image_compress`
  /// bounds the *shorter* side, so 384 gives ~512 px on a 4:3 photo.
  static const int thumbMaxSide = 384;
  static const int thumbTargetBytes = 80 * 1024;
}

class PreparedImage {
  const PreparedImage({required this.upload, required this.thumbnail});

  /// JPEG sent to `POST /analyze-food`.
  final Uint8List upload;

  /// JPEG stored locally as the food photo.
  final Uint8List thumbnail;
}

/// Compresses a captured photo before it is sent to the AI proxy.
///
/// The picker already limits the photo to 1024 px on its longest side
/// (see `ScannerController`), so this step mainly enforces the byte size.
class ImagePreparer {
  const ImagePreparer();

  Future<PreparedImage> prepare(String path) async {
    final upload = await _compress(
      path,
      ImageLimits.uploadMaxSide,
      ImageLimits.uploadMaxBytes,
    );
    final thumb = await _compress(
      path,
      ImageLimits.thumbMaxSide,
      ImageLimits.thumbTargetBytes,
    );
    return PreparedImage(upload: upload, thumbnail: thumb);
  }

  Future<Uint8List> _compress(String path, int maxSide, int maxBytes) async {
    Uint8List? best;
    for (final quality in const [85, 70, 55, 40]) {
      final out = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: maxSide,
        minHeight: maxSide,
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
