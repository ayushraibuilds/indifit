import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/presentation/daypart_greeting.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/coaching/b04_production_surface_controller.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/food_log/ai_meal_logger_screen.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/onboarding/b05_adaptive_onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('UX-R1 local daypart greeting', () {
    final cases = <DateTime, String>{
      DateTime(2026, 8, 9, 4, 59): 'Hi',
      DateTime(2026, 8, 9, 5): 'Good morning',
      DateTime(2026, 8, 9, 11, 59): 'Good morning',
      DateTime(2026, 8, 9, 12): 'Good afternoon',
      DateTime(2026, 8, 9, 16, 59): 'Good afternoon',
      DateTime(2026, 8, 9, 17): 'Good evening',
      DateTime(2026, 8, 9, 21, 59): 'Good evening',
      DateTime(2026, 8, 9, 22): 'Hi',
    };

    for (final entry in cases.entries) {
      test('${entry.key.hour}:${entry.key.minute} uses ${entry.value}', () {
        expect(daypartGreeting(entry.key), entry.value);
      });
    }
  });

  testWidgets('AI failure keeps input and opens manual food search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'offline_only': true});
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase.memory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          foodLogsForDayProvider.overrideWith((ref, date) async => []),
          privacyPolicyProvider.overrideWith(
            (ref) => PrivacyPolicyNotifier(prefs),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: AiMealLoggerScreen(
            mealType: 'dinner',
            selectedDate: DateTime(2026, 8, 7),
          ),
        ),
      ),
    );
    await tester.pump();

    final description = find.byType(TextField).first;
    await tester.enterText(description, '2 rotis with dal');
    await tester.pump();
    await tester.ensureVisible(find.text('Estimate nutrition'));
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Estimate unavailable'), findsOneWidget);
    expect(find.text('Search foods instead'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('Search foods instead'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(FoodSearchScreen), findsOneWidget);
    final fallbackSearch = tester.widget<FoodSearchScreen>(
      find.byType(FoodSearchScreen),
    );
    expect(fallbackSearch.mealType, 'dinner');
    expect(fallbackSearch.selectedDate, DateTime(2026, 8, 7));

    Navigator.of(tester.element(find.byType(FoodSearchScreen))).pop();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final restoredField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    expect(restoredField.controller?.text, '2 rotis with dal');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('skipped setup keeps the B04 production context fail-closed', () async {
    SharedPreferences.setMockInitialValues({});
    const store = B05OnboardingDraftStore();
    await store.markProfileOnboardingSkipped();

    final database = AppDatabase.memory();
    final loader = B04ProductionUserContextLoader(
      database: database,
      dates: LocalScheduleDateService(),
      timezones: LocalTimezoneService(),
    );
    expect(loader.load(), throwsA(isA<B04ProductionSurfaceError>()));
    await database.close();
  });

  test('skipped setup keeps basic Today reads available', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'onboarding_skipped': true,
    });
    final database = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        nutritionRegistryProvider.overrideWith((ref) async => registry),
        localTimezoneServiceProvider.overrideWithValue(
          LocalTimezoneService(read: () async => 'Asia/Kolkata'),
        ),
      ],
    );
    final snapshot = await container.read(
      todaySurfaceSnapshotProvider(DateTime(2026, 8, 8)).future,
    );
    expect(snapshot.calendar.isAvailable, isTrue);
    expect(snapshot.progress.isAvailable, isTrue);
    expect(snapshot.nutrition.isAvailable, isTrue);
    expect(snapshot.nutrition.value!.records, isEmpty);
    expect(await database.select(database.userProfiles).get(), isEmpty);
    container.dispose();
    await database.close();
  });

  testWidgets(
    'Breakfast search saves canonically and refreshes the Today read model',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'onboarding_skipped': true,
        'offline_only': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final database = AppDatabase.memory();
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      await tester.runAsync(
        () => database
            .into(database.foodItems)
            .insert(
              FoodItemsCompanion.insert(
                name: 'Review oats',
                calories: 250,
                proteinG: 10,
                carbsG: 0,
                fatG: 5,
                servingSize: 100,
                servingUnit: 'g',
                category: 'breakfast',
              ),
            ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          nutritionRegistryProvider.overrideWith((ref) async => registry),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(read: () async => 'Asia/Kolkata'),
          ),
          privacyPolicyProvider.overrideWith(
            (ref) => PrivacyPolicyNotifier(prefs),
          ),
        ],
      );
      final selectedDate = DateTime(2026, 8, 8);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        container.dispose();
        await database.close();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: _BreakfastReflectionHarness(selectedDate: selectedDate),
          ),
        ),
      );
      await _pumpLiveSurface(tester);
      expect(find.text('Breakfast entries: 0'), findsOneWidget);

      await tester.tap(find.text('Add breakfast'));
      await _pumpLiveSurface(tester);
      expect(find.byType(FoodSearchScreen), findsOneWidget);
      expect(find.text('Log breakfast'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Review oats');
      await tester.pump(const Duration(milliseconds: 500));
      await _pumpLiveSurface(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Review oats'));
      await _pumpLiveSurface(tester, cycles: 20);
      expect(find.text('Log to BREAKFAST'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      await tester.tap(find.text('Add Meal'));
      await _pumpLiveSurface(tester, cycles: 20);

      expect(find.byType(FoodSearchScreen), findsNothing);
      expect(find.text('Breakfast entries: 1'), findsOneWidget);
      final day = await tester.runAsync(() async {
        final readModels = await container.read(
          nutritionReadModelRepositoryProvider.future,
        );
        return readModels.dailyTotals(
          userId: kLocalNutritionUserScopeId,
          localDate: '2026-08-08',
        );
      });
      expect(day, isNotNull);
      final persistedDay = day!;
      expect(persistedDay.records, hasLength(1));
      expect(persistedDay.records.single.mealCategory, 'breakfast');
      expect(persistedDay.records.single.sourceType, 'canonical_snapshot');
      expect(
        persistedDay.records.single.items.single.originSourceType,
        'direct_food',
      );
      expect(
        persistedDay.records.single.items.single.sourceReference,
        isNotEmpty,
      );
      expect(
        persistedDay
            .records
            .single
            .items
            .single
            .facts['carbohydrate']!
            .point!
            .value
            .toString(),
        '0',
      );
      expect(
        persistedDay.records.single.items.single.facts['fibre']!.isAvailable,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  test(
    'skipped onboarding survives backup without fabricating a profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'onboarding_skipped': true,
      });
      final sourcePreferences = await SharedPreferences.getInstance();
      final source = AppDatabase.memory();
      final backup = await BackupData.createFromDatabase(
        source,
        sourcePreferences,
      );
      await source.close();
      expect(backup.userPreferences['onboarding_skipped'], isTrue);

      SharedPreferences.setMockInitialValues({});
      final restoredPreferences = await SharedPreferences.getInstance();
      final target = AppDatabase.memory();
      await backup.restoreToDatabase(target, restoredPreferences);
      expect(restoredPreferences.getBool('onboarding_completed'), isTrue);
      expect(restoredPreferences.getBool('onboarding_skipped'), isTrue);

      final notifier = UserProfileNotifier(target);
      await notifier.loadProfile();
      expect(await target.select(target.userProfiles).get(), isEmpty);
      notifier.dispose();
      await target.close();
    },
  );
}

class _BreakfastReflectionHarness extends ConsumerWidget {
  const _BreakfastReflectionHarness({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(todaySurfaceSnapshotProvider(selectedDate));
    final records = snapshot.valueOrNull?.nutrition.value?.records;
    final breakfastCount = records
        ?.where((record) => record.mealCategory == 'breakfast')
        .length;
    return Scaffold(
      body: Column(
        children: [
          Text(
            breakfastCount == null
                ? 'Breakfast entries: loading'
                : 'Breakfast entries: $breakfastCount',
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => FoodSearchScreen(
                  mealType: 'breakfast',
                  selectedDate: selectedDate,
                ),
              ),
            ),
            child: const Text('Add breakfast'),
          ),
        ],
      ),
    );
  }
}

Future<void> _pumpLiveSurface(WidgetTester tester, {int cycles = 12}) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  for (var i = 0; i < cycles; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
