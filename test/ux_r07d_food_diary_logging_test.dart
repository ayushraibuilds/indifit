import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // R07F-0: Outfit is bundled; no runtime font fetching configuration.

  test(
    'custom food preserves missingness, known zero, and household label',
    () async {
      final fixture = await _R07DFixture.create();
      addTearDown(fixture.close);

      final option = await fixture.catalog.createUserFood(
        displayName: 'Test poha',
        servingSize: 1,
        servingUnit: 'katori',
        energyKcal: 230,
        proteinG: null,
        carbohydrateG: 42,
        fatG: 0,
      );

      expect(option.baseQuantity.unit, QuantityUnit.serving);
      expect(option.servingUnitLabel, '1 katori');
      expect(option.facts['energy']!.basis.kind, NutrientBasisKind.perServing);
      expect(option.facts['protein']!.status, NutrientFactStatus.missing);
      expect(option.facts['protein']!.point, isNull);
      expect(option.facts['fat']!.status, NutrientFactStatus.knownZero);

      final preview = await fixture.logger.preview(
        option: option,
        quantity: Quantity.serving(
          amount: '1.25',
          definition: option.baseQuantity.context.servingDefinition!,
          source: 'user',
        ),
      );
      expect(preview.facts['protein']!.status, NutrientFactStatus.missing);
      expect(preview.facts['fat']!.status, NutrientFactStatus.knownZero);
      expect(preview.quantity.amount.toString(), '1.25');
    },
  );

  test('batch logging is atomic, date/meal scoped, and idempotent', () async {
    final fixture = await _R07DFixture.create();
    addTearDown(fixture.close);

    final first = await fixture.catalog.createUserFood(
      displayName: 'Batch rice',
      servingSize: 1,
      servingUnit: 'katori',
      energyKcal: 220,
      proteinG: 4,
      carbohydrateG: 45,
      fatG: 1,
    );
    final second = await fixture.catalog.createUserFood(
      displayName: 'Batch dal',
      servingSize: 1,
      servingUnit: 'katori',
      energyKcal: 180,
      proteinG: null,
      carbohydrateG: 25,
      fatG: 3,
    );
    final previews = await Future.wait([
      fixture.logger.preview(
        option: first,
        quantity: Quantity.serving(
          amount: '1.25',
          definition: first.baseQuantity.context.servingDefinition!,
          source: 'user',
        ),
      ),
      fixture.logger.preview(option: second, quantity: second.baseQuantity),
    ]);

    final firstCommit = await fixture.logger.finalizeBatch(
      userId: fixture.userId,
      previews: previews,
      mealCategory: 'lunch',
      loggedAt: DateTime.utc(2026, 8, 13, 12),
      localDate: '2026-08-13',
      timezoneId: 'Asia/Kolkata',
      consumptionId: 'r07d-batch-consumption',
      commandId: 'r07d-batch-command',
    );
    final retry = await fixture.logger.finalizeBatch(
      userId: fixture.userId,
      previews: previews,
      mealCategory: 'lunch',
      loggedAt: DateTime.utc(2026, 8, 13, 12),
      localDate: '2026-08-13',
      timezoneId: 'Asia/Kolkata',
      consumptionId: 'r07d-batch-consumption',
      commandId: 'r07d-batch-command',
    );

    expect(retry.id, firstCommit.id);
    expect(firstCommit.localDate, '2026-08-13');
    expect(firstCommit.mealCategory, 'lunch');
    expect(firstCommit.items, hasLength(2));
    expect(firstCommit.items.first.quantity.amount.toString(), '1.25');
    expect(
      firstCommit.items[1].facts['protein']!.status,
      NutrientFactStatus.missing,
    );

    final snapshots = await fixture.consumption.listAllForUser(
      userId: fixture.userId,
    );
    expect(snapshots, hasLength(1));
    final daily = await fixture.readModels.dailyTotals(
      userId: fixture.userId,
      localDate: '2026-08-13',
    );
    expect(daily.records, hasLength(1));
    expect(daily.records.single.mealCategory, 'lunch');
    expect(daily.totals.facts['protein']!.isAvailable, isTrue);
    expect(daily.totals.facts['protein']!.coverageIncomplete, isTrue);
  });

  testWidgets(
    'multi-select preserves temporary selection and commits one batch per tap burst',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final fixture = await _R07DFixture.create();
      final countingLogger = _CountingBatchCoordinator(
        db: fixture.db,
        registry: fixture.registry,
        catalog: fixture.catalog,
        consumption: fixture.consumption,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        unawaited(fixture.close());
      });
      final options = (await tester.runAsync(() async {
        final result = <NutritionFoodOption>[];
        for (final name in const ['Rice', 'Dal', 'Paneer', 'Curd']) {
          result.add(
            await fixture.catalog.createUserFood(
              displayName: name,
              servingSize: 1,
              servingUnit: 'serving',
              energyKcal: 100,
              proteinG: 5,
              carbohydrateG: 10,
              fatG: 2,
            ),
          );
        }
        return result;
      }))!;
      final recent = [
        for (var index = 0; index < options.length; index++)
          CanonicalRecentFood(
            option: options[index],
            quantityLabel: '1 serving',
            loggedAtUtc: DateTime.utc(2026, 8, 13, 10, index),
          ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(fixture.db),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'Asia/Kolkata'),
            ),
            nutritionRegistryProvider.overrideWith(
              (ref) async => fixture.registry,
            ),
            nutritionFoodCatalogRepositoryProvider.overrideWith(
              (ref) async => fixture.catalog,
            ),
            nutritionConsumptionRepositoryProvider.overrideWith(
              (ref) async => fixture.consumption,
            ),
            nutritionFoodLoggingCoordinatorProvider.overrideWith(
              (ref) async => countingLogger,
            ),
            foodRepositoryProvider.overrideWithValue(
              _EmptyFoodRepository(fixture.db),
            ),
            canonicalRecentFoodsProvider.overrideWith((ref) async => recent),
            foodLogsForDayProvider.overrideWith((ref, date) async => []),
            canonicalFoodRecordsForDayProvider.overrideWith(
              (ref, date) async => [],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: FoodSearchScreen(
              mealType: 'lunch',
              selectedDate: DateTime(2026, 8, 13),
              initialMultiSelect: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      var checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(4));
      for (final name in const ['Rice', 'Dal', 'Paneer', 'Curd']) {
        final checkbox = find.bySemanticsLabel(
          'Select $name for a multi-food add',
        );
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
      }
      expect(find.text('ADD 4 FOODS TO LUNCH'), findsOneWidget);
      expect(find.text('4 foods selected · 400 kcal'), findsOneWidget);

      final curdCheckbox = find.bySemanticsLabel(
        'Select Curd for a multi-food add',
      );
      await tester.ensureVisible(curdCheckbox);
      await tester.tap(curdCheckbox);
      await tester.pump();
      expect(find.text('ADD 3 FOODS TO LUNCH'), findsOneWidget);
      expect(find.text('3 foods selected · 300 kcal'), findsOneWidget);
      await expectLater(
        find.byType(FoodSearchScreen),
        matchesGoldenFile('goldens/ux_r07d_multiselect_light.png'),
      );

      final batchAdd = find.widgetWithText(
        FilledButton,
        'ADD 3 FOODS TO LUNCH',
      );
      final batchAddPosition = tester.getCenter(batchAdd);
      await tester.tapAt(batchAddPosition);
      await tester.tapAt(batchAddPosition);
      await tester.pump();
      expect(countingLogger.batchCalls, 1);
      await _settleR07D(tester);
      expect(find.text('ADD 3 FOODS TO LUNCH'), findsNothing);
    },
  );

  testWidgets(
    'fast add uses an explicit serving and ignores a rapid second tap',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final fixture = await _R07DFixture.create();
      final trackingLogger = _TrackingFastAddCoordinator(
        db: fixture.db,
        registry: fixture.registry,
        catalog: fixture.catalog,
        consumption: fixture.consumption,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        unawaited(fixture.close());
      });
      final options = (await tester.runAsync(() async {
        final serving = await fixture.catalog.createUserFood(
          displayName: 'Test poha',
          servingSize: 1,
          servingUnit: 'katori',
          energyKcal: 230,
          proteinG: 5,
          carbohydrateG: 42,
          fatG: 4,
        );
        return serving;
      }))!;
      final recent = [
        CanonicalRecentFood(
          option: options,
          quantityLabel: '1 katori',
          loggedAtUtc: DateTime.utc(2026, 8, 12, 9),
        ),
      ];

      await tester.pumpWidget(
        _r07dFoodApp(
          fixture: fixture,
          recent: recent,
          logger: trackingLogger,
          home: FoodSearchScreen(
            mealType: 'lunch',
            selectedDate: DateTime(2026, 8, 12),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final servingAdd = find.bySemanticsLabel('Add Test poha');
      expect(servingAdd, findsOneWidget);
      final servingAddPosition = tester.getCenter(servingAdd);
      await tester.tapAt(servingAddPosition);
      await tester.pump();
      expect(trackingLogger.directCalls, 1);
      await tester.tapAt(servingAddPosition);
      await tester.pump();
      expect(trackingLogger.directCalls, 1);
      expect(
        find.byKey(const ValueKey('food_quantity_review_surface')),
        findsNothing,
      );
      expect(trackingLogger.localDate, '2026-08-12');
      expect(trackingLogger.mealCategory, 'lunch');
      expect(trackingLogger.quantity?.unit, QuantityUnit.serving);
    },
  );

  testWidgets('populated diary keeps meal totals and food names in view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final fixture = await _R07DFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      unawaited(fixture.close());
    });
    await tester.runAsync(() async {
      final poha = await fixture.catalog.createUserFood(
        displayName: 'Diary poha',
        servingSize: 1,
        servingUnit: 'katori',
        energyKcal: 230,
        proteinG: 5,
        carbohydrateG: 42,
        fatG: 4,
      );
      final rice = await fixture.catalog.createUserFood(
        displayName: 'Diary rice',
        servingSize: 1,
        servingUnit: 'katori',
        energyKcal: 220,
        proteinG: 4,
        carbohydrateG: 45,
        fatG: 1,
      );
      final dal = await fixture.catalog.createUserFood(
        displayName: 'Diary dal',
        servingSize: 1,
        servingUnit: 'katori',
        energyKcal: 180,
        proteinG: 9,
        carbohydrateG: 25,
        fatG: 3,
      );
      final loggedAt = DateTime.utc(2026, 8, 12, 7);
      Future<void> log(
        NutritionFoodOption option,
        String meal,
        String id,
      ) async {
        final preview = await fixture.logger.preview(
          option: option,
          quantity: option.baseQuantity,
        );
        await fixture.logger.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: preview,
          mealCategory: meal,
          loggedAt: loggedAt,
          localDate: '2026-08-12',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r07d-diary-$id-command',
          consumptionId: 'r07d-diary-$id-consumption',
        );
      }

      await log(poha, 'breakfast', 'poha');
      await log(rice, 'lunch', 'rice');
      await log(dal, 'lunch', 'dal');
    });

    await tester.pumpWidget(
      _r07dFoodApp(
        fixture: fixture,
        home: FoodDiaryScreen(
          selectedDate: DateTime(2026, 8, 12),
          today: DateTime(2026, 8, 13),
        ),
      ),
    );
    await _settleR07D(tester);

    expect(find.text('Diary poha'), findsOneWidget);
    expect(find.text('Diary dal · Diary rice'), findsOneWidget);
    await expectLater(
      find.byType(FoodDiaryScreen),
      matchesGoldenFile('goldens/ux_r07d_diary_populated_light.png'),
    );
  });

  testWidgets(
    'food diary date navigation carries the selected historical day into meal add',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final fixture = await _R07DFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        unawaited(fixture.close());
      });

      await tester.pumpWidget(
        _r07dFoodApp(
          fixture: fixture,
          home: FoodDiaryScreen(
            selectedDate: DateTime(2026, 8, 12),
            today: DateTime(2026, 8, 13),
          ),
        ),
      );
      await _settleR07D(tester);

      expect(find.text('Yesterday'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next day'));
      await _settleR07D(tester);
      expect(find.text('Today'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Previous day'));
      await _settleR07D(tester);
      expect(find.text('Yesterday'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Today'));
      await _settleR07D(tester);
      expect(find.text('Today'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Previous day'));
      await _settleR07D(tester);
      await tester.tap(find.bySemanticsLabel('Add Lunch'));
      await _settleR07D(tester);
      final search = tester.widget<FoodSearchScreen>(
        find.byType(FoodSearchScreen),
      );
      expect(search.mealType, 'lunch');
      expect(search.selectedDate, DateTime(2026, 8, 12));
    },
  );

  testWidgets('food diary remains legible at 430px / 1.5x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    final fixture = await _R07DFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      unawaited(fixture.close());
    });

    await tester.pumpWidget(
      _r07dFoodApp(
        fixture: fixture,
        textScale: 1.5,
        home: FoodDiaryScreen(
          selectedDate: DateTime(2026, 8, 12),
          today: DateTime(2026, 8, 13),
        ),
      ),
    );
    await _settleR07D(tester);

    final addBreakfast = find.bySemanticsLabel('Add Breakfast');
    expect(addBreakfast, findsOneWidget);
    expect(tester.getRect(addBreakfast).bottom, lessThanOrEqualTo(932));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(FoodDiaryScreen),
      matchesGoldenFile('goldens/ux_r07d_diary_430_1_5_light.png'),
    );
  });

  testWidgets('mass-basis fast add requires quantity confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final fixture = await _R07DFixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      unawaited(fixture.close());
    });
    final mass = await tester.runAsync(
      () => fixture.catalog.ensureLegacyFood(
        const FoodItem(
          id: 4001,
          name: 'Measured paneer',
          calories: 300,
          proteinG: 24,
          carbsG: 6,
          fatG: 21,
          servingSize: 100,
          servingUnit: 'g',
          category: 'Protein',
          isCustom: false,
        ),
      ),
    );

    await tester.pumpWidget(
      _r07dFoodApp(
        fixture: fixture,
        recent: [
          CanonicalRecentFood(
            option: mass!,
            quantityLabel: '100 g',
            loggedAtUtc: DateTime.utc(2026, 8, 12, 10),
          ),
        ],
        home: FoodSearchScreen(
          mealType: 'lunch',
          selectedDate: DateTime(2026, 8, 12),
        ),
      ),
    );
    await _settleR07D(tester);

    await tester.tap(find.bySemanticsLabel('Add Measured paneer'));
    await _settleR07D(tester);
    expect(find.text('Log to LUNCH'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food_quantity_review_surface')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('food_quantity_review_surface')),
      ),
    ).pop(false);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('food_quantity_review_surface')),
      findsNothing,
    );
  });

  testWidgets(
    'quantity sheet keeps its final action reachable at compact 2x text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      final fixture = await _R07DFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        unawaited(fixture.close());
      });
      final mass = await tester.runAsync(
        () => fixture.catalog.ensureLegacyFood(
          const FoodItem(
            id: 4002,
            name: 'Compact paneer',
            calories: 300,
            proteinG: 24,
            carbsG: 6,
            fatG: 21,
            servingSize: 100,
            servingUnit: 'g',
            category: 'Protein',
            isCustom: false,
          ),
        ),
      );

      await tester.pumpWidget(
        _r07dFoodApp(
          fixture: fixture,
          textScale: 2,
          recent: [
            CanonicalRecentFood(
              option: mass!,
              quantityLabel: '100 g',
              loggedAtUtc: DateTime.utc(2026, 8, 12, 10),
            ),
          ],
          home: FoodSearchScreen(
            mealType: 'lunch',
            selectedDate: DateTime(2026, 8, 12),
          ),
        ),
      );
      await _settleR07D(tester);

      final fastAdd = find.bySemanticsLabel('Add Compact paneer');
      final landingScroll = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      expect(landingScroll, findsOneWidget);
      await tester.drag(landingScroll, const Offset(0, -180));
      await tester.pump();
      await tester.tap(fastAdd);
      await _settleR07D(tester);
      await tester.pumpAndSettle();
      final addAction = find.widgetWithText(ElevatedButton, 'Add to Lunch');
      final quantitySurface = find.byKey(
        const ValueKey('food_quantity_review_surface'),
      );
      final quantityScroll = find.descendant(
        of: quantitySurface,
        matching: find.byType(SingleChildScrollView),
      );
      expect(quantityScroll, findsOneWidget);
      await tester.drag(quantityScroll, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.getRect(addAction).bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
      await expectLater(
        quantitySurface,
        matchesGoldenFile('goldens/ux_r07d_quantity_compact_2x_light.png'),
      );
    },
  );
}

Widget _r07dFoodApp({
  required _R07DFixture fixture,
  required Widget home,
  List<CanonicalRecentFood> recent = const [],
  NutritionFoodLoggingCoordinator? logger,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(fixture.db),
    localTimezoneServiceProvider.overrideWithValue(
      LocalTimezoneService(read: () async => 'Asia/Kolkata'),
    ),
    nutritionRegistryProvider.overrideWith((ref) async => fixture.registry),
    nutritionFoodCatalogRepositoryProvider.overrideWith(
      (ref) async => fixture.catalog,
    ),
    nutritionConsumptionRepositoryProvider.overrideWith(
      (ref) async => fixture.consumption,
    ),
    nutritionReadModelRepositoryProvider.overrideWith(
      (ref) async => fixture.readModels,
    ),
    nutritionFoodLoggingCoordinatorProvider.overrideWith(
      (ref) async => logger ?? fixture.logger,
    ),
    foodRepositoryProvider.overrideWithValue(_EmptyFoodRepository(fixture.db)),
    canonicalRecentFoodsProvider.overrideWith((ref) async => recent),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  ),
);

Future<void> _settleR07D(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

class _R07DFixture {
  _R07DFixture._(
    this.db,
    this.registry,
    this.catalog,
    this.consumption,
    this.logger,
    this.readModels,
  );

  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionFoodCatalogRepository catalog;
  final NutritionConsumptionRepository consumption;
  final NutritionFoodLoggingCoordinator logger;
  final NutritionReadModelRepository readModels;
  final String userId = 'r07d-test-user';

  static Future<_R07DFixture> create() async {
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final transformations = NutritionTransformationRepository(db: db);
    final readModels = NutritionReadModelRepository(
      db: db,
      registry: registry,
      canonicalRepository: consumption,
    );
    final logger = NutritionFoodLoggingCoordinator(
      db: db,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: transformations,
    );
    return _R07DFixture._(
      db,
      registry,
      catalog,
      consumption,
      logger,
      readModels,
    );
  }

  Future<void> close() => db.close();
}

class _CountingBatchCoordinator extends NutritionFoodLoggingCoordinator {
  _CountingBatchCoordinator({
    required super.db,
    required super.registry,
    required super.catalog,
    required super.consumption,
  }) : super(
         calculator: const NutritionCalculationService(),
         transformations: NutritionTransformationRepository(db: db),
       );

  int batchCalls = 0;

  @override
  Future<NutritionConsumptionSnapshot> finalizeBatch({
    required String userId,
    required Iterable<NutritionFoodLogPreview> previews,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    String? mealGroupId,
    String? consumptionId,
    String? commandId,
  }) {
    batchCalls++;
    return Future.value(
      _testConsumptionSnapshot(
        userId: userId,
        loggedAt: loggedAt,
        mealCategory: mealCategory,
        localDate: localDate,
        timezoneId: timezoneId,
        id: 'test-batch-snapshot',
      ),
    );
  }
}

class _TrackingFastAddCoordinator extends NutritionFoodLoggingCoordinator {
  _TrackingFastAddCoordinator({
    required super.db,
    required super.registry,
    required super.catalog,
    required super.consumption,
  }) : super(
         calculator: const NutritionCalculationService(),
         transformations: NutritionTransformationRepository(db: db),
       );

  int directCalls = 0;
  String? mealCategory;
  String? localDate;
  Quantity? quantity;
  final Completer<NutritionConsumptionSnapshot> _completion = Completer();

  @override
  Future<NutritionConsumptionSnapshot> finalize({
    required String userId,
    required NutritionFoodLogPreview preview,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    String? mealGroupId,
    String? consumptionId,
    String? commandId,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
  }) {
    directCalls++;
    this.mealCategory = mealCategory;
    this.localDate = localDate;
    quantity = preview.quantity;
    return _completion.future;
  }
}

NutritionConsumptionSnapshot _testConsumptionSnapshot({
  required String id,
  required String userId,
  required DateTime loggedAt,
  required String mealCategory,
  required String localDate,
  required String timezoneId,
}) {
  final completeness = NutrientCompleteness(
    state: NutrientCompletenessState.unknown,
    requestedNutrientIds: const ['energy'],
    availableNutrientIds: const [],
    missingNutrientIds: const ['energy'],
    estimatedNutrientIds: const [],
    notApplicableNutrientIds: const [],
    partiallyKnownNutrientIds: const [],
  );
  return NutritionConsumptionSnapshot(
    id: id,
    userId: userId,
    loggedAtUtc: loggedAt,
    mealCategory: mealCategory,
    mealGroupId: null,
    sourceType: 'direct_food',
    recipeVersionId: null,
    thaliId: null,
    calculatorVersion: 'test',
    completeness: completeness,
    totals: NutrientAggregationResult(
      facts: const {},
      completeness: completeness,
      sourceLineage: const {},
      factVersionLineage: const {},
    ),
    localDate: localDate,
    timezoneId: timezoneId,
    createdAtUtc: loggedAt,
    lineage: NutritionConsumptionLineage(contentFingerprint: 'test-$id'),
    items: const [],
  );
}

class _EmptyFoodRepository extends FoodRepository {
  _EmptyFoodRepository(super.database);

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => const [];
}
