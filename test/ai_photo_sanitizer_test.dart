import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:indifit/core/ai/ai_photo_sanitizer.dart';

/// A landscape JPEG shot "sideways" (orientation 6 = rotate 90° to view),
/// tagged with a location and phone model, like a real gallery photo.
Uint8List _phonePhoto({int width = 400, int height = 200}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  image.exif.imageIfd
    ..make = 'TestPhone'
    ..model = 'TP-1'
    ..orientation = 6;
  image.exif.gpsIfd
    ..gpsLatitudeRef = 'N'
    ..gpsLatitude = 28.6139
    ..gpsLongitudeRef = 'E'
    ..gpsLongitude = 77.2090;
  return img.encodeJpg(image);
}

/// Finds the bytes "Exif" anywhere in the file, i.e. any APP1 EXIF segment.
bool _containsExifSegment(Uint8List jpeg) {
  const marker = [0x45, 0x78, 0x69, 0x66]; // "Exif"
  for (var i = 0; i + marker.length <= jpeg.length; i++) {
    var match = true;
    for (var j = 0; j < marker.length; j++) {
      if (jpeg[i + j] != marker[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

void main() {
  group('AiPhotoSanitizer', () {
    test('the test photo really carries GPS and device metadata', () {
      final original = img.decodeJpg(_phonePhoto())!;
      expect(original.exif.gpsIfd.gpsLatitude, closeTo(28.6139, 0.001));
      expect(original.exif.imageIfd.make, 'TestPhone');
    });

    test('removes all EXIF, including location', () {
      final cleaned = AiPhotoSanitizer.sanitizeSync(
        _phonePhoto(),
        maxDimension: 1024,
      );

      expect(_containsExifSegment(cleaned), isFalse);
      final decoded = img.decodeJpg(cleaned)!;
      expect(decoded.exif.isEmpty, isTrue);
      expect(decoded.exif.gpsIfd.hasGPSLatitude, isFalse);
      expect(decoded.exif.imageIfd.make, isNull);
    });

    test('keeps the photo upright once the orientation tag is gone', () {
      final cleaned = img.decodeJpg(
        AiPhotoSanitizer.sanitizeSync(_phonePhoto(), maxDimension: 1024),
      )!;

      // Orientation 6 turns the 400x200 sensor image into a 200x400 portrait.
      expect(cleaned.width, 200);
      expect(cleaned.height, 400);
    });

    test('caps the longest side at maxDimension, keeping the aspect', () {
      final cleaned = img.decodeJpg(
        AiPhotoSanitizer.sanitizeSync(
          _phonePhoto(width: 3000, height: 1500),
          maxDimension: 1024,
        ),
      )!;

      expect(cleaned.height, 1024); // upright portrait after orientation 6
      expect(cleaned.width, 512);
    });

    test('does not enlarge small photos', () {
      final cleaned = img.decodeJpg(
        AiPhotoSanitizer.sanitizeSync(_phonePhoto(), maxDimension: 2048),
      )!;
      expect(cleaned.height, 400);
    });

    test('refuses data it cannot decode instead of sending it as-is', () {
      expect(
        () => AiPhotoSanitizer.sanitizeSync(
          Uint8List.fromList([1, 2, 3, 4]),
          maxDimension: 1024,
        ),
        throwsA(isA<AiPhotoUnreadableException>()),
      );
    });

    test('sanitize runs the same work off the UI isolate', () async {
      final cleaned = await AiPhotoSanitizer.sanitize(
        _phonePhoto(),
        maxDimension: 1024,
      );
      expect(_containsExifSegment(cleaned), isFalse);
    });
  });
}
