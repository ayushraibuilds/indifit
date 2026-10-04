import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Thrown when a photo can't be decoded, so it is never sent as-is.
class AiPhotoUnreadableException implements Exception {
  const AiPhotoUnreadableException();

  @override
  String toString() => 'AiPhotoUnreadableException';
}

/// Re-encodes photos without their metadata before they leave the device.
///
/// Camera and gallery photos carry EXIF: GPS location, capture time, device
/// make and model. `image_picker` keeps it when it resizes (Android copies
/// the GPS tags; iOS copies the original metadata), and the consent sheet
/// promises that only the photo itself is sent. So every AI photo is decoded,
/// turned upright (EXIF orientation is applied to the pixels, since the tag
/// that carried it is dropped), capped at [maxDimension] and written as a
/// fresh JPEG with no EXIF or ICC profile.
///
/// A photo that can't be decoded throws [AiPhotoUnreadableException] rather
/// than being sent unprocessed.
abstract final class AiPhotoSanitizer {
  /// Meal photos: enough detail to tell dishes apart.
  static const int mealMaxDimension = 1024;

  /// Nutrition labels: small printed text needs more pixels.
  static const int labelMaxDimension = 2048;

  static const int _jpegQuality = 85;

  /// [sanitizeSync] on a background isolate, so decoding never janks the UI.
  static Future<Uint8List> sanitize(
    Uint8List bytes, {
    required int maxDimension,
  }) => Isolate.run(() => sanitizeSync(bytes, maxDimension: maxDimension));

  static Uint8List sanitizeSync(Uint8List bytes, {required int maxDimension}) {
    final decoded = _decode(bytes);
    if (decoded == null) throw const AiPhotoUnreadableException();

    var image = img.bakeOrientation(decoded);
    final longest = math.max(image.width, image.height);
    if (longest > maxDimension) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxDimension)
          : img.copyResize(image, height: maxDimension);
    }

    // The JPEG encoder writes whatever EXIF and ICC data the image carries.
    image
      ..exif = img.ExifData()
      ..iccProfile = null;
    return img.encodeJpg(image, quality: _jpegQuality);
  }

  static img.Image? _decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } on Object {
      // Corrupt or unsupported data; treated as unreadable.
      return null;
    }
  }
}
