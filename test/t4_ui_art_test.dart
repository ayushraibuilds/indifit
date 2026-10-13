import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/presentation/ui_art.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/data/models/hydration_models.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/dashboard/widgets/hydration_fluid_fill.dart';
import 'package:indifit/features/dashboard/widgets/hydration_glass.dart';
import 'package:indifit/features/dashboard/widgets/today_hydration_card.dart';
import 'package:indifit/features/dashboard/widgets/today_module_widgets.dart';
import 'package:indifit/features/food_log/meal_presentation_registry.dart';
import 'package:indifit/features/food_log/widgets/meal_icon_chip.dart';

/// T4 (Today review 12 Oct, "Depth and 3D"): Fluent Emoji 3D art for meals
/// and water, one meal chip everywhere, and the water row as a glass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('art and provenance', () {
    test('every file matches SOURCE.md, and nothing else is in the folder', () {
      final source = File('assets/ui_icons/SOURCE.md').readAsStringSync();
      for (final path in UiArt.all) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final name = path.split('/').last;
        final digest = sha256.convert(file.readAsBytesSync()).toString();
        expect(
          RegExp('\\| $name \\|.*\\| $digest \\|').hasMatch(source),
          isTrue,
          reason: '$name checksum matches SOURCE.md',
        );
      }
      final onDisk = Directory('assets/ui_icons')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.png'))
          .toSet();
      expect(onDisk, {for (final p in UiArt.all) p.split('/').last});
    });

    test('the manifest source covers UI art and says so', () {
      final manifest = File(
        'assets/third_party/asset_manifest.json',
      ).readAsStringSync();
      expect(manifest, contains('"approved_badge_and_ui_art"'));
      expect(manifest, contains('assets/ui_icons/SOURCE.md'));
    });

    test('the pinned commit is the same as the badges', () {
      const commit = '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc';
      expect(
        File('assets/ui_icons/SOURCE.md').readAsStringSync(),
        contains(commit),
      );
      expect(
        File('assets/badges/SOURCE.md').readAsStringSync(),
        contains(commit),
      );
    });
  });

  group('MealPresentationRegistry', () {
    test('the four canonical slots and every snack slot have art', () {
      expect(MealPresentationRegistry.breakfast.art, UiArt.mealBreakfast);
      expect(MealPresentationRegistry.lunch.art, UiArt.mealLunch);
      expect(MealPresentationRegistry.dinner.art, UiArt.mealDinner);
      for (final snack in [
        MealPresentationRegistry.snack,
        MealPresentationRegistry.morningSnack,
        MealPresentationRegistry.afternoonSnack,
        MealPresentationRegistry.eveningSnack,
        MealPresentationRegistry.lateSnack,
      ]) {
        expect(snack.art, UiArt.mealSnack, reason: snack.stableId);
      }
    });

    test('workout slots and unknown keep an icon', () {
      expect(MealPresentationRegistry.preWorkout.art, isNull);
      expect(MealPresentationRegistry.postWorkout.art, isNull);
      expect(MealPresentationRegistry.unknown.art, isNull);
    });

    test('every art path is a real file', () {
      for (final slot in MealPresentationRegistry.allSupported) {
        final art = slot.art;
        if (art != null) expect(File(art).existsSync(), isTrue, reason: art);
      }
    });
  });

  // The chips decode a resized copy (cacheWidth), so let the real asset read
  // finish instead of precaching the full-size image.
  Future<void> decode(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  void useSmallPhone(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host(ThemeData theme, Widget child, {bool reduceMotion = true}) =>
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(402, 600),
              disableAnimations: reduceMotion,
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => ColoredBox(
                  color: context.b05Colors.page,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(
                        key: const Key('t4_host'),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  const meals = [
    TodayMealPresentation(
      mealType: 'breakfast',
      label: 'Breakfast',
      detail: 'Poha, Chai',
      calorieLabel: '320 kcal',
      kcal: 320,
      logged: true,
      nutritionIncomplete: false,
      itemCount: 2,
      itemLabels: ['Poha', 'Chai'],
    ),
    TodayMealPresentation(
      mealType: 'lunch',
      label: 'Lunch',
      detail: 'Not logged',
      calorieLabel: '—',
      logged: false,
      nutritionIncomplete: false,
      itemCount: 0,
      itemLabels: [],
    ),
    TodayMealPresentation(
      mealType: 'dinner',
      label: 'Dinner',
      detail: 'Not logged',
      calorieLabel: '—',
      logged: false,
      nutritionIncomplete: false,
      itemCount: 0,
      itemLabels: [],
    ),
    TodayMealPresentation(
      mealType: 'snack',
      label: 'Snacks',
      detail: 'Not logged',
      calorieLabel: '—',
      logged: false,
      nutritionIncomplete: false,
      itemCount: 0,
      itemLabels: [],
    ),
  ];

  Widget mealsModule() => TodayMealsModule(
    meals: meals,
    loading: false,
    unavailable: false,
    onLogMeal: (_) {},
    onRetry: () {},
    selectedDate: DateTime(2026, 10, 13),
  );

  Widget water(int ml) => TodayHydrationCard(
    hydrationRead: TodayDomainRead.available(
      HydrationDailyReadModel(
        localDate: '2026-10-13',
        totalMl: ml,
        goalMl: 2500,
      ),
    ),
    selectedDate: DateTime(2026, 10, 13),
  );

  group('goldens', () {
    for (final (name, theme) in [
      ('dark', AppTheme.darkTheme),
      ('light', AppTheme.lightTheme),
    ]) {
      testWidgets('meals, $name', tags: const ['golden'], (tester) async {
        useSmallPhone(tester, const Size(402, 600));
        await tester.pumpWidget(host(theme, mealsModule()));
        await decode(tester);
        await expectLater(
          find.byKey(const Key('t4_host')),
          matchesGoldenFile('goldens/t4_today_meals_$name.png'),
        );
      });

      for (final (label, ml) in [
        ('empty', 0),
        ('half', 1250),
        ('goal', 2500),
      ]) {
        testWidgets('water $label, $name', tags: const ['golden'], (
          tester,
        ) async {
          useSmallPhone(tester, const Size(402, 600));
          await tester.pumpWidget(host(theme, water(ml)));
          await decode(tester);
          await expectLater(
            find.byKey(const Key('t4_host')),
            matchesGoldenFile('goldens/t4_today_water_${label}_$name.png'),
          );
        });
      }
    }
  });

  group('widgets', () {
    testWidgets('Today meal rows draw the registry art', (tester) async {
      useSmallPhone(tester, const Size(402, 600));
      await tester.pumpWidget(host(AppTheme.darkTheme, mealsModule()));
      await decode(tester);
      final chips = tester.widgetList<MealIconChip>(find.byType(MealIconChip));
      expect(chips.map((c) => c.presentation.art), [
        UiArt.mealBreakfast,
        UiArt.mealLunch,
        UiArt.mealDinner,
        UiArt.mealSnack,
      ]);
      expect(find.byType(Image), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a slot without art draws its icon', (tester) async {
      await tester.pumpWidget(
        host(
          AppTheme.darkTheme,
          const MealIconChip(presentation: MealPresentationRegistry.preWorkout),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    });

    testWidgets('the water row has a glass, and the droplet chip', (
      tester,
    ) async {
      useSmallPhone(tester, const Size(402, 600));
      await tester.pumpWidget(host(AppTheme.darkTheme, water(1250)));
      await decode(tester);
      expect(find.byType(HydrationGlass), findsOneWidget);
      expect(find.text('1,250 / 2,500 ml'), findsOneWidget);
      expect(find.text('1,250 ml remaining'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      final asset = provider is ResizeImage ? provider.imageProvider : provider;
      expect((asset as AssetImage).assetName, UiArt.water);
    });

    testWidgets('the glass fills with the day, and turns green at the goal', (
      tester,
    ) async {
      useSmallPhone(tester, const Size(402, 600));
      await tester.pumpWidget(host(AppTheme.darkTheme, water(2500)));
      await decode(tester);
      final glass = tester.widget<HydrationGlass>(find.byType(HydrationGlass));
      expect(glass.progress, 1.0);
      expect(glass.isGoalMet, isTrue);
      expect(find.text('Goal met!'), findsOneWidget);
    });

    testWidgets('animated motion uses the fluid fill painter', (tester) async {
      useSmallPhone(tester, const Size(402, 600));
      await tester.pumpWidget(
        host(AppTheme.lightTheme, water(1250), reduceMotion: false),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(HydrationFluidFillIndicator), findsOneWidget);
    });
  });
}
