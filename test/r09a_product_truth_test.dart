import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/config/app_config.dart';
import 'package:indifit/core/fixtures/food_identity_manifest.dart';
import 'package:indifit/core/router/app_router.dart';

void main() {
  group('R09-A offline-first V1 product contract', () {
    test('release startup is independent of the legacy backend', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final workflow = File('.github/workflows/ci.yml').readAsStringSync();

      // Tests run in debug mode, where the AI tools are off by default.
      expect(AppConfig.connectedAiEnabled, isFalse);
      expect(mainSource, isNot(contains('validateBootstrapConfig')));
      expect(mainSource, isNot(contains('INDIFIT_API_KEY')));
      expect(
        workflow,
        isNot(
          contains('flutter build apk --release --dart-define=INDIFIT_API_KEY'),
        ),
      );
      expect(
        workflow,
        isNot(
          contains(
            'flutter build ios --release --no-codesign --dart-define=INDIFIT_API_KEY',
          ),
        ),
      );
    });

    test('all retired AI deep links redirect to reviewed V1 surfaces', () {
      final container = ProviderContainer(
        overrides: [onboardingCompletedProvider.overrideWith((ref) => true)],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final routes = router.configuration.routes.whereType<GoRoute>();

      for (final path in const [
        '/food/ai',
        '/meal-planner',
        '/routine-wizard',
        '/weekly-report',
      ]) {
        expect(
          routes.singleWhere((route) => route.path == path).redirect,
          isNotNull,
          reason: '$path must not mount a retired AI surface in V1',
        );
      }
    });

    test('iOS usage descriptions cover barcodes, labels and meal photos', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('scan food barcodes and nutrition labels'));
      expect(plist, contains('photograph meals you choose to estimate'));
      expect(plist, contains('NSPhotoLibraryUsageDescription'));
      expect(plist, contains('photo of a nutrition label or a meal'));
      expect(plist, isNot(contains('NSMicrophoneUsageDescription')));
      expect(plist, isNot(contains('AI macro estimation')));
    });

    test('release-facing copy contains no retired or inflated claims', () {
      final readme = File('README.md').readAsStringSync();
      final listing = File('doc/store_listing_copy.md').readAsStringSync();
      final privacy = File('doc/privacy_policy.md').readAsStringSync();

      for (final source in [readme, listing, privacy]) {
        expect(source, isNot(contains('1,000+ curated')));
        expect(source, isNot(contains('413 common Indian')));
        expect(source, isNot(contains('AI Photo & Text')));
        expect(source, isNot(contains('using encrypted storage capabilities')));
        expect(source, isNot(contains('your data never leaves your device')));
      }
      // Counts come from the catalogue itself: retired duplicates leave
      // search, so they don't count.
      List<dynamic> foods(String path) =>
          jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
      final base =
          foods('assets/data/indian_foods.json').length -
          kRetiredCatalogueFoods.length;
      final regional = Directory('assets/data/regional')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .fold<int>(0, (sum, file) => sum + foods(file.path).length);
      expect(readme, contains('$base base food entries'));
      expect(readme, contains('$regional optional regional-pack entries'));
      expect(listing, contains('$base Indian foods built in'));
      expect(listing, contains('$regional more in optional regional packs'));
      expect(privacy, contains('Open Food Facts'));
      expect(privacy, contains('not password-protected in V1'));
    });

    test('legacy routine display contains no retired AI call to action', () {
      final source = File(
        'lib/features/workout_player/routine_display_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('/routine-wizard')));
      expect(source, isNot(contains('Generate Split with AI')));
      expect(source, isNot(contains('AI Fitness Coach')));
      expect(source, contains('Browse plans'));
    });
  });
}
