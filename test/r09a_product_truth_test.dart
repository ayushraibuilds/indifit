import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/config/app_config.dart';
import 'package:indifit/core/router/app_router.dart';

void main() {
  group('R09-A offline-first V1 product contract', () {
    test('release startup is independent of the legacy backend', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final workflow = File('.github/workflows/ci.yml').readAsStringSync();

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

    test('iOS usage descriptions expose only the V1 camera purpose', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('scan a food barcode'));
      expect(plist, isNot(contains('NSMicrophoneUsageDescription')));
      expect(plist, isNot(contains('NSPhotoLibraryUsageDescription')));
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
      expect(readme, contains('573 base food entries'));
      expect(listing, contains('25 optional regional-pack entries'));
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
