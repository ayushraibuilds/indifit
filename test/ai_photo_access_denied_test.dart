import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:indifit/core/config/app_links.dart';
import 'package:indifit/core/privacy/nutrition_estimate_privacy.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/features/nutrition/nutrition_providers.dart';
import 'package:indifit/features/nutrition_ai/nutrition_ai_controllers.dart';
import 'package:indifit/features/nutrition_ai/nutrition_label_ocr_service.dart';
import 'package:indifit/features/nutrition_ai/photo_meal_screen.dart';

/// Audit UX-10: a refused camera or photo permission is not an AI failure.
void main() {
  PhotoMealController photoController(ImagePicker picker) =>
      PhotoMealController(
        mealService: () async => throw StateError('no scan without a photo'),
        catalogRepository: () async => throw StateError('unused'),
        loggingCoordinator: () async => throw StateError('unused'),
        userId: 'test-user',
        timezoneId: () async => 'Asia/Kolkata',
        picker: picker,
      );

  group('Meal photo controller', () {
    test('a refused camera says so and remembers the source', () async {
      final controller = photoController(_DeniedPicker('camera_access_denied'));

      await controller.pickAndScan(ImageSource.camera, deviceUuid: 'device');

      expect(controller.state.status, PhotoMealStatus.failure);
      expect(controller.state.deniedSource, ImageSource.camera);
      expect(controller.state.errorMessage, startsWith('Camera access is off'));
    });

    test('a refused photo library names photos, not the camera', () async {
      final controller = photoController(_DeniedPicker('photo_access_denied'));

      await controller.pickAndScan(ImageSource.gallery, deviceUuid: 'device');

      expect(controller.state.deniedSource, ImageSource.gallery);
      expect(controller.state.errorMessage, startsWith('Photo access is off'));
    });

    test('other picker failures stay generic', () async {
      final controller = photoController(_DeniedPicker('invalid_image'));

      await controller.pickAndScan(ImageSource.camera, deviceUuid: 'device');

      expect(controller.state.status, PhotoMealStatus.failure);
      expect(controller.state.deniedSource, isNull);
      expect(
        controller.state.errorMessage,
        startsWith('Could not analyze meal photo'),
      );
    });
  });

  test('label scan: a refused camera explains itself', () async {
    final controller = NutritionLabelOcrController(
      ocrService: NutritionLabelOcrService(
        dio: Dio(),
        privacyService: NutritionEstimatePrivacyService(),
        policy: () => const PrivacyPolicy(
          isOfflineOnly: false,
          isTelemetryEnabled: false,
        ),
      ),
      catalogRepository: () async => throw StateError('unused'),
      loggingCoordinator: () async => throw StateError('unused'),
      userId: 'test-user',
      timezoneId: () async => 'Asia/Kolkata',
      picker: _DeniedPicker('camera_access_denied'),
    );

    await controller.pickAndScan(ImageSource.camera);

    expect(controller.state.status, NutritionLabelOcrStatus.failure);
    expect(controller.state.errorMessage, startsWith('Camera access is off'));
  });

  group('Meal photo screen', () {
    Future<void> pumpDenied(WidgetTester tester) async {
      final controller = photoController(_DeniedPicker('camera_access_denied'));
      await controller.pickAndScan(ImageSource.camera, deviceUuid: 'device');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photoMealControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: PhotoMealScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('iOS offers the gallery and Settings, not a dead retry', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final opened = <Uri>[];
      final previousLauncher = AppLinks.launcher;
      AppLinks.launcher = (uri) async {
        opened.add(uri);
        return true;
      };
      addTearDown(() => AppLinks.launcher = previousLauncher);

      await pumpDenied(tester);

      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.text('Could not analyze photo'), findsNothing);
      expect(find.text('Try Again'), findsNothing);
      expect(find.text('Choose from Gallery'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(opened, [Uri.parse('app-settings:')]);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android asks for the camera again instead of Settings', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await pumpDenied(tester);

      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
      expect(find.text('Ask for Camera Again'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

class _DeniedPicker extends ImagePicker {
  _DeniedPicker(this.code);

  final String code;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => throw PlatformException(code: code);
}
