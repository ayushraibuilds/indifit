import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:indifit/core/ai/ai_gateway.dart';
import 'package:indifit/core/ai/ai_photo_sanitizer.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/privacy/nutrition_estimate_privacy.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';
import 'package:indifit/features/nutrition_ai/nutrition_label_ocr_service.dart';

/// Records the photo bytes that would be sent to the model.
class _RecordingGateway implements AiGateway {
  final sent = <Uint8List>[];

  @override
  Future<Map<String, dynamic>> decomposeMealText(String text) async => const {
    'items': <Object>[],
  };

  @override
  Future<Map<String, dynamic>> decomposeMealPhoto(Uint8List jpeg) async {
    sent.add(jpeg);
    return const {'items': <Object>[], 'total_calories': 0};
  }

  @override
  Future<Map<String, dynamic>> readNutritionLabel(Uint8List jpeg) async {
    sent.add(jpeg);
    return const {'basis': 'per_100g', 'nutrients': <String, Object>{}};
  }
}

const _aiAllowed = PrivacyPolicy(
  isOfflineOnly: false,
  isTelemetryEnabled: false,
  connectedAiEnabled: true,
);

/// A gallery photo tagged with where it was taken.
Uint8List _photoWithLocation() {
  final image = img.Image(width: 64, height: 48);
  image.exif.gpsIfd
    ..gpsLatitudeRef = 'N'
    ..gpsLatitude = 19.0760
    ..gpsLongitudeRef = 'E'
    ..gpsLongitude = 72.8777;
  return img.encodeJpg(image);
}

bool _hasLocation(Uint8List jpeg) =>
    img.decodeJpg(jpeg)!.exif.gpsIfd.hasGPSLatitude;

void main() {
  // The database seeds the food catalogue from assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File photo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('indifit_photo_meta');
    photo = File('${dir.path}/photo.jpg');
    await photo.writeAsBytes(_photoWithLocation());
    expect(_hasLocation(await photo.readAsBytes()), isTrue);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('meal photos', () {
    late AppDatabase db;
    late NutritionFoodCatalogRepository catalog;

    setUp(() {
      db = AppDatabase.memory();
      catalog = NutritionFoodCatalogRepository(
        db: db,
        registry: NutrientRegistry.fromAssetFileSync(
          'assets/data/nutrient_registry.json',
        ),
      );
    });

    tearDown(() => db.close());

    NaturalLanguageMealService service(AiGateway gateway) =>
        NaturalLanguageMealService(
          gateway: gateway,
          catalog: catalog,
          policy: () => _aiAllowed,
        );

    test('are sent without their location', () async {
      final gateway = _RecordingGateway();
      await service(
        gateway,
      ).decomposePhotoMeal(imagePath: photo.path, deviceUuid: 'device');

      expect(gateway.sent, hasLength(1));
      expect(_hasLocation(gateway.sent.single), isFalse);
    });

    test('that cannot be decoded are never sent', () async {
      await photo.writeAsBytes([1, 2, 3, 4]);
      final gateway = _RecordingGateway();

      await expectLater(
        service(
          gateway,
        ).decomposePhotoMeal(imagePath: photo.path, deviceUuid: 'device'),
        throwsA(isA<AiPhotoUnreadableException>()),
      );
      expect(gateway.sent, isEmpty);
    });
  });

  group('nutrition labels', () {
    NutritionLabelOcrService service(AiGateway gateway) =>
        NutritionLabelOcrService(
          gateway: gateway,
          privacyService: NutritionEstimatePrivacyService(),
          policy: () => _aiAllowed,
        );

    test('are sent without their location', () async {
      final gateway = _RecordingGateway();
      await service(gateway).processLabelImage(imagePath: photo.path);

      expect(gateway.sent, hasLength(1));
      expect(_hasLocation(gateway.sent.single), isFalse);
    });

    test(
      'that cannot be decoded are never sent, and are still deleted',
      () async {
        await photo.writeAsBytes([1, 2, 3, 4]);
        final gateway = _RecordingGateway();

        await expectLater(
          service(gateway).processLabelImage(imagePath: photo.path),
          throwsA(isA<AiPhotoUnreadableException>()),
        );
        expect(gateway.sent, isEmpty);
        expect(await photo.exists(), isFalse);
      },
    );
  });
}
