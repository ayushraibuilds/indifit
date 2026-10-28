import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/voice/on_device_speech.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/widgets/food_search_bar.dart';
import 'package:indifit/features/nutrition_ai/spoken_meal_parser.dart';
import 'package:indifit/features/voice/voice_mic_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_catalogue.dart';

/// A speech engine with no platform behind it.
class FakeVoiceEngine implements VoiceEngine {
  FakeVoiceEngine({
    this.supported = const {VoiceLocale.englishIndia, VoiceLocale.hindi},
    this.reason = 'no_on_device_recognizer',
    this.permitted = false,
    this.grant = true,
    this.heard = 'do roti aur dal',
  });

  final Set<VoiceLocale> supported;
  final String reason;
  bool permitted;
  final bool grant;
  final String heard;
  int permissionRequests = 0;
  final List<VoiceLocale> listened = [];

  @override
  Future<OnDeviceSpeechSupport> onDeviceSupport(VoiceLocale locale) async =>
      supported.contains(locale)
      ? const OnDeviceSpeechSupport.available()
      : OnDeviceSpeechSupport.unavailable(reason);

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permitted = grant;
    return grant;
  }

  @override
  Future<void> listen(
    VoiceLocale locale, {
    required void Function(String words, bool isFinal) onWords,
    required void Function(String error) onError,
  }) async {
    listened.add(locale);
    onWords(heard, true);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('spoken meal parser', () {
    test('splits on aur, and, with and commas', () {
      expect(
        SpokenMealParser.split('do roti aur ek katori dal, salad with raita'),
        ['2 roti', '1 katori dal', 'salad', 'raita'],
      );
      expect(SpokenMealParser.split('2 idli and sambar'), ['2 idli', 'sambar']);
      expect(SpokenMealParser.split('दो रोटी और दाल'), ['2 रोटी', 'दाल']);
    });

    test('Hindi number words become amounts', () {
      expect(
        SpokenMealParser.normaliseNumbers('aadha glass doodh'),
        '0.5 glass doodh',
      );
      expect(SpokenMealParser.normaliseNumbers('dedh roti'), '1.5 roti');
      expect(
        SpokenMealParser.normaliseNumbers('dhai katori chawal'),
        '2.5 katori chawal',
      );
      expect(SpokenMealParser.normaliseNumbers('teen idli'), '3 idli');
      expect(SpokenMealParser.normaliseNumbers('char puri'), '4 puri');
      expect(SpokenMealParser.normaliseNumbers('paanch badam'), '5 badam');
      expect(
        SpokenMealParser.normaliseNumbers('dal ek katori'),
        'dal 1 katori',
      );
      expect(SpokenMealParser.normaliseNumbers('roti do'), 'roti 2');
      // A dish's own name keeps its words.
      expect(
        SpokenMealParser.normaliseNumbers('bhindi do pyaza'),
        'bhindi do pyaza',
      );
      expect(SpokenMealParser.normaliseNumbers('do'), 'do');
    });

    group('against the catalogue', () {
      late RealCatalogue c;
      late SpokenFoodLookup lookup;
      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        c = await RealCatalogue.open();
        lookup = spokenFoodLookup(FoodRepository(c.db), c.catalog);
      });
      tearDown(() => c.close());

      test(
        'Hinglish parts become catalogue items with their amounts',
        () async {
          final parse = await SpokenMealParser.parse(
            'do roti aur ek katori dal',
            lookup,
          );
          expect(parse.notFound, isEmpty);
          expect(parse.items, hasLength(2));
          final roti = parse.items.first;
          expect(roti.matchedCatalogOption, isNotNull);
          expect(
            roti.foodName.toLowerCase(),
            anyOf(contains('roti'), contains('chapati')),
          );
          expect(roti.rawSegment, '2 roti');
          // Nutrition comes from the catalogue, never a guess.
          expect(roti.estimatedCalories, greaterThan(0));
          final dal = parse.items.last;
          expect(dal.matchedCatalogOption, isNotNull);
          expect(dal.quantityAmount, 1);
        },
      );

      test('a part with no food is listed as not found', () async {
        final parse = await SpokenMealParser.parse(
          'ek roti aur qwertyzxv',
          lookup,
        );
        expect(parse.items, hasLength(1));
        expect(parse.notFound, ['qwertyzxv']);
      });
    });
  });

  group('Android API gate', () {
    const channel = MethodChannel('com.indifit.indifit/speech_on_device');
    final calls = <MethodCall>[];

    PluginVoiceEngine android(Map<String, Object?> reply) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'onDeviceSupport' ? reply : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      return PluginVoiceEngine(platform: TargetPlatform.android);
    }

    setUp(calls.clear);

    test('API 31 is the first level allowed', () {
      expect(kAndroidOnDeviceSpeechMinSdk, 31);
      expect(androidAllowsOnDeviceSpeech(null), isFalse);
      expect(androidAllowsOnDeviceSpeech(30), isFalse);
      expect(androidAllowsOnDeviceSpeech(31), isTrue);
      expect(androidAllowsOnDeviceSpeech(34), isTrue);
    });

    test(
      'below API 31 the mic is hidden, whatever the platform says',
      () async {
        final engine = android({'available': true, 'sdk': 30});
        final support = await engine.onDeviceSupport(VoiceLocale.englishIndia);
        expect(support.available, isFalse);
        expect(support.reason, 'os_too_old');

        final container = ProviderContainer(
          overrides: [voiceEngineProvider.overrideWithValue(engine)],
        );
        addTearDown(container.dispose);
        final availability = await container.read(
          voiceInputAvailabilityProvider.future,
        );
        expect(availability.isAvailable, isFalse);
        expect(
          availability.summary,
          'Needs Android 12 or later for on-device speech',
        );
      },
    );

    test('a reply without its API level counts as too old', () async {
      final support = await android({
        'available': true,
      }).onDeviceSupport(VoiceLocale.englishIndia);
      expect(support.reason, 'os_too_old');
    });

    test('API 31 with the language on the device shows the mic', () async {
      final engine = android({'available': true, 'sdk': 31});
      final support = await engine.onDeviceSupport(VoiceLocale.englishIndia);
      expect(support.available, isTrue);
      expect(calls.single.arguments, {'locale': 'en-IN'});
    });

    test('API 33 without the language says to download it', () async {
      final support = await android({
        'available': false,
        'reason': 'language_not_downloaded',
        'sdk': 33,
      }).onDeviceSupport(VoiceLocale.englishIndia);
      expect(support.reason, 'language_not_downloaded');
    });
  });

  group('mic', () {
    Widget searchBar(FakeVoiceEngine engine, {List<String>? said}) {
      return ProviderScope(
        overrides: [voiceEngineProvider.overrideWithValue(engine)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FoodSearchBar(
                controller: TextEditingController(),
                voiceAction: VoiceMicButton.maybe(
                  ref,
                  onTranscript: (words) => said?.add(words),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('is hidden when no language is recognised on the device', (
      tester,
    ) async {
      await tester.pumpWidget(searchBar(FakeVoiceEngine(supported: const {})));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('shows when English (India) is on the device', (tester) async {
      await tester.pumpWidget(
        searchBar(FakeVoiceEngine(supported: const {VoiceLocale.englishIndia})),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    test('availability says why, and ignores Offline Mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          voiceEngineProvider.overrideWithValue(
            FakeVoiceEngine(supported: const {}, reason: 'os_too_old'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final off = await container.read(voiceInputAvailabilityProvider.future);
      expect(off.isAvailable, isFalse);
      expect(off.summary, 'Needs Android 12 or later for on-device speech');

      final on = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          voiceEngineProvider.overrideWithValue(FakeVoiceEngine()),
        ],
      );
      addTearDown(on.dispose);
      await on.read(privacyPolicyProvider.notifier).setOfflineOnly(true);
      expect(on.read(privacyPolicyProvider).isOfflineOnly, isTrue);
      final available = await on.read(voiceInputAvailabilityProvider.future);
      // Hindi is held back for now: English (India) only.
      expect(available.locales, [VoiceLocale.englishIndia]);
    });

    testWidgets('explains before the system prompt, then listens', (
      tester,
    ) async {
      final engine = FakeVoiceEngine();
      final said = <String>[];
      await tester.pumpWidget(searchBar(engine, said: said));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Recognised on this phone'), findsOneWidget);
      expect(engine.permissionRequests, 0);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(engine.permissionRequests, 0);
      expect(said, isEmpty);

      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow microphone'));
      await tester.pumpAndSettle();
      expect(engine.permissionRequests, 1);
      expect(engine.listened, [VoiceLocale.englishIndia]);
      expect(said, ['do roti aur dal']);

      // Allowed once: the next tap listens straight away.
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Recognised on this phone'), findsNothing);
      expect(engine.permissionRequests, 1);
      expect(said, hasLength(2));
    });

    testWidgets('a declined system prompt says how to turn it on', (
      tester,
    ) async {
      final engine = FakeVoiceEngine(grant: false);
      final said = <String>[];
      await tester.pumpWidget(searchBar(engine, said: said));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow microphone'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The microphone is off'), findsOneWidget);
      expect(engine.listened, isEmpty);
      expect(said, isEmpty);
    });
  });
}
