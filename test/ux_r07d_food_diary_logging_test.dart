import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
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
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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
    'multi-select preserves temporary selection and exposes batch commit CTA',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      final fixture = await _R07DFixture.create();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await fixture.close();
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
              (ref) async => fixture.logger,
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

      final curdCheckbox = find.bySemanticsLabel(
        'Select Curd for a multi-food add',
      );
      await tester.ensureVisible(curdCheckbox);
      await tester.tap(curdCheckbox);
      await tester.pump();
      expect(find.text('ADD 3 FOODS TO LUNCH'), findsOneWidget);
    },
  );
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

class _EmptyFoodRepository extends FoodRepository {
  _EmptyFoodRepository(super.database);

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => const [];
}
