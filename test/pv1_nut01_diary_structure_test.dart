import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/food_log/diary_structure_controller.dart';
import 'package:indifit/features/food_log/meal_presentation_registry.dart';
import 'package:indifit/features/settings/diary_structure_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PV1-NUT-01 MealPresentationRegistry Contract', () {
    test('canonical default values contains strictly the 4 meals', () {
      expect(MealPresentationRegistry.values, hasLength(4));
      expect(
        MealPresentationRegistry.values.map((m) => m.stableId).toList(),
        ['breakfast', 'lunch', 'dinner', 'snack'],
      );
    });

    test('allSupported contains all 10 supported slots', () {
      expect(MealPresentationRegistry.allSupported, hasLength(10));
      final allIds = MealPresentationRegistry.allSupported.map((m) => m.stableId).toList();
      expect(allIds, containsAll([
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'morning_snack',
        'afternoon_snack',
        'evening_snack',
        'pre_workout',
        'post_workout',
        'late_snack',
      ]));
    });

    test('forStableId resolves canonical and optional slots with trimming and normalization', () {
      expect(MealPresentationRegistry.forStableId('breakfast').stableId, 'breakfast');
      expect(MealPresentationRegistry.forStableId('lunch').stableId, 'lunch');
      expect(MealPresentationRegistry.forStableId('dinner').stableId, 'dinner');
      expect(MealPresentationRegistry.forStableId('snack').stableId, 'snack');
      // Legacy normalization
      expect(MealPresentationRegistry.forStableId('snacks').stableId, 'snack');
      // Case and whitespace tolerance
      expect(MealPresentationRegistry.forStableId('  Morning_Snack  ').stableId, 'morning_snack');
      expect(MealPresentationRegistry.forStableId('PRE_WORKOUT').stableId, 'pre_workout');
      expect(MealPresentationRegistry.forStableId('post_workout').label, 'Post-workout');
      expect(MealPresentationRegistry.forStableId('late_snack').isKnown, isTrue);

      // Unknown IDs
      final unknown = MealPresentationRegistry.forStableId('midnight_feast');
      expect(unknown.isKnown, isFalse);
      expect(unknown.stableId, 'unknown');
      expect(unknown.label, 'Meal category unknown');
    });
  });

  group('PV1-NUT-01 DiaryStructureController & Sanitization Contract', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with standard4 preset when preferences are empty', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = DiaryStructureController(prefs);

      expect(controller.state.activeSlotIds, ['breakfast', 'lunch', 'dinner', 'snack']);
      expect(controller.state.activeSlots, hasLength(4));
    });

    test('sanitizeSlotIds drops unknown IDs and dedupes while preserving order', () {
      final raw = ['breakfast', 'corrupt_id', 'breakfast', 'afternoon_snack', 'unknown_xyz'];
      final sanitized = DiaryStructureController.sanitizeSlotIds(raw);

      expect(sanitized, ['breakfast', 'afternoon_snack']);
    });

    test('sanitizeSlotIds safely falls back to standard4 when empty or entirely corrupt', () {
      expect(
        DiaryStructureController.sanitizeSlotIds(null),
        DiaryStructurePreset.standard4.slotIds,
      );
      expect(
        DiaryStructureController.sanitizeSlotIds([]),
        DiaryStructurePreset.standard4.slotIds,
      );
      expect(
        DiaryStructureController.sanitizeSlotIds(['garbage1', 'garbage2']),
        DiaryStructurePreset.standard4.slotIds,
      );
    });

    test('addSlot adds valid optional slot and is idempotent', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = DiaryStructureController(prefs);

      await controller.addSlot('morning_snack');
      expect(controller.state.activeSlotIds, [
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'morning_snack',
      ]);
      expect(prefs.getStringList(prefDiaryMealSlotsKey), controller.state.activeSlotIds);

      // Idempotent: adding existing slot is a no-op
      await controller.addSlot('morning_snack');
      expect(controller.state.activeSlotIds, [
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'morning_snack',
      ]);

      // Adding unknown slot is ignored
      await controller.addSlot('invalid_slot');
      expect(controller.state.activeSlotIds, [
        'breakfast',
        'lunch',
        'dinner',
        'snack',
        'morning_snack',
      ]);
    });

    test('removeSlot enforces minimum 1 slot invariant', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = DiaryStructureController(prefs);

      // Remove down to 1
      await controller.removeSlot('snack');
      await controller.removeSlot('dinner');
      await controller.removeSlot('lunch');
      expect(controller.state.activeSlotIds, ['breakfast']);

      // Attempting to remove last slot must be rejected
      await controller.removeSlot('breakfast');
      expect(controller.state.activeSlotIds, ['breakfast']);
    });

    test('reorderSlots correctly updates order and bounds check', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = DiaryStructureController(prefs);

      // Move 'snack' (index 3) to top (index 0)
      await controller.reorderSlots(3, 0);
      expect(controller.state.activeSlotIds, ['snack', 'breakfast', 'lunch', 'dinner']);

      // Out of bounds is safely ignored
      await controller.reorderSlots(-1, 2);
      await controller.reorderSlots(0, 99);
      expect(controller.state.activeSlotIds, ['snack', 'breakfast', 'lunch', 'dinner']);
    });

    test('presets and resetToDefault behavior', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = DiaryStructureController(prefs);

      // Apply 3 meals
      await controller.applyPreset(DiaryStructurePreset.threeMeals);
      expect(controller.state.activeSlotIds, ['breakfast', 'lunch', 'dinner']);
      expect(prefs.getStringList(prefDiaryMealSlotsKey), ['breakfast', 'lunch', 'dinner']);

      // Apply athlete6
      await controller.applyPreset(DiaryStructurePreset.athlete6);
      expect(controller.state.activeSlotIds, DiaryStructurePreset.athlete6.slotIds);

      // Reset to default removes key from preferences
      await controller.resetToDefault();
      expect(controller.state.activeSlotIds, ['breakfast', 'lunch', 'dinner', 'snack']);
      expect(prefs.getStringList(prefDiaryMealSlotsKey), isNull);
    });
  });

  group('PV1-NUT-01 Backup Allowlist Contract', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('BackupData exports and round-trips pref_diary_meal_slots through JSON', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final prefs = await SharedPreferences.getInstance();
      final customSlots = ['breakfast', 'lunch', 'dinner'];
      await prefs.setStringList(prefDiaryMealSlotsKey, customSlots);

      final backup = await BackupData.createFromDatabase(db, prefs);
      expect(backup.userPreferences[prefDiaryMealSlotsKey], customSlots);

      final json = backup.toJson();
      final userPrefs = json['user_preferences'] as Map<String, dynamic>;
      expect(userPrefs[prefDiaryMealSlotsKey], customSlots);

      final restored = BackupData.fromJson(json);
      expect(restored.userPreferences[prefDiaryMealSlotsKey], customSlots);
    });
  });

  group('PV1-NUT-01 Router Parsing Contract', () {
    test('parseFoodRouteMealType accepts all 10 supported slots and normalizes snacks', () {
      expect(parseFoodRouteMealType('breakfast'), 'breakfast');
      expect(parseFoodRouteMealType('lunch'), 'lunch');
      expect(parseFoodRouteMealType('dinner'), 'dinner');
      expect(parseFoodRouteMealType('snack'), 'snack');
      expect(parseFoodRouteMealType('snacks'), 'snack');
      expect(parseFoodRouteMealType('morning_snack'), 'morning_snack');
      expect(parseFoodRouteMealType('afternoon_snack'), 'afternoon_snack');
      expect(parseFoodRouteMealType('evening_snack'), 'evening_snack');
      expect(parseFoodRouteMealType('pre_workout'), 'pre_workout');
      expect(parseFoodRouteMealType('post_workout'), 'post_workout');
      expect(parseFoodRouteMealType('late_snack'), 'late_snack');

      // Invalid strings
      expect(parseFoodRouteMealType(null), isNull);
      expect(parseFoodRouteMealType(''), isNull);
      expect(parseFoodRouteMealType('brunch'), isNull);
      expect(parseFoodRouteMealType('dessert'), isNull);
    });
  });

  group('PV1-NUT-01 Coordinator Logging Contract', () {
    test('correctLoggedFood validates supported meals and allows optional slots', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );
      final catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
      final consumption = NutritionConsumptionRepository(db: db, registry: registry);
      final coordinator = NutritionFoodLoggingCoordinator(
        db: db,
        registry: registry,
        catalog: catalog,
        calculator: const NutritionCalculationService(),
        consumption: consumption,
        transformations: NutritionTransformationRepository(db: db),
      );

      // Unsupported meal throws unsupported_food_correction_meal
      await expectLater(
        coordinator.correctDirectFoodItem(
          userId: 'user-1',
          snapshotId: 'snap-1',
          itemId: 'item-1',
          expectedMealCategory: 'breakfast',
          mealCategory: 'brunch',
          localDate: '2026-09-10',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: DateTime.utc(2026, 9, 10, 8),
          commandId: 'cmd-1',
          correctionReason: 'test',
        ),
        throwsA(
          isA<NutritionFoodLoggingError>().having(
            (e) => e.code,
            'code',
            'unsupported_food_correction_meal',
          ),
        ),
      );

      // Optional slot (e.g. morning_snack, pre_workout) passes meal validation gate
      // and only fails downstream on missing snapshot predecessor
      await expectLater(
        coordinator.correctDirectFoodItem(
          userId: 'user-1',
          snapshotId: 'snap-1',
          itemId: 'item-1',
          expectedMealCategory: 'morning_snack',
          mealCategory: 'pre_workout',
          localDate: '2026-09-10',
          timezoneId: 'Asia/Kolkata',
          loggedAtUtc: DateTime.utc(2026, 9, 10, 8),
          commandId: 'cmd-1',
          correctionReason: 'test',
        ),
        throwsA(
          isA<NutritionFoodLoggingError>().having(
            (e) => e.code,
            'code',
            'missing_food_correction_predecessor',
          ),
        ),
      );
    });
  });

  group('PV1-NUT-01 Historic Slot Preservation Contract', () {
    test('TodayNutritionPresentation preserves unconfigured historic slots with logged records', () {
      // User configured only 3 meals: breakfast, lunch, dinner
      final configuredMeals = [
        ('breakfast', 'Breakfast'),
        ('lunch', 'Lunch'),
        ('dinner', 'Dinner'),
      ];

      // Historical records include breakfast, lunch, AND a morning snack & evening snack
      final records = [
        const _FixtureRecord(
          stableId: 'rec-1',
          mealCategory: 'breakfast',
          displayLabel: 'Oatmeal',
          calories: 350,
        ),
        const _FixtureRecord(
          stableId: 'rec-2',
          mealCategory: 'morning_snack',
          displayLabel: 'Almonds',
          calories: 160,
        ),
        const _FixtureRecord(
          stableId: 'rec-3',
          mealCategory: 'lunch',
          displayLabel: 'Rice & Dal',
          calories: 500,
        ),
        const _FixtureRecord(
          stableId: 'rec-4',
          mealCategory: 'evening_snack',
          displayLabel: 'Tea & Toast',
          calories: 120,
        ),
      ];

      final daily = NutritionDailyReadModel(
        userId: 'user-1',
        localDate: '2026-09-01',
        records: records,
        recordIds: records.map((r) => r.stableId).toList(),
        totals: _aggregation({
          'energy': _known('energy', 1130, NutrientUnit.kilocalorie),
        }),
        sourceCounts: const {},
        issues: const [],
      );

      final presentation = TodayNutritionPresentation.from(
        TodayDomainRead.available(daily),
        loading: false,
        configuredMeals: configuredMeals,
      );

      // The presentation meals must contain the 3 configured slots PLUS morning_snack and evening_snack!
      final mealTypes = presentation.meals.map((m) => m.mealType).toList();
      expect(mealTypes, [
        'breakfast',
        'lunch',
        'dinner',
        'morning_snack',
        'evening_snack',
      ]);

      // Verify unconfigured historical meals have their data intact
      final morningSnack = presentation.meals.firstWhere((m) => m.mealType == 'morning_snack');
      expect(morningSnack.logged, isTrue);
      expect(morningSnack.itemCount, 1);
      expect(morningSnack.label, 'Morning snack');

      final eveningSnack = presentation.meals.firstWhere((m) => m.mealType == 'evening_snack');
      expect(eveningSnack.logged, isTrue);
      expect(eveningSnack.itemCount, 1);
      expect(eveningSnack.label, 'Evening snack');

      // Unlogged dinner remains visible because it is configured
      final dinner = presentation.meals.firstWhere((m) => m.mealType == 'dinner');
      expect(dinner.logged, isFalse);
      expect(dinner.detail, 'Tap + to add');
    });
  });

  group('PV1-NUT-01 DiaryStructureScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders screen with info banner, presets, active and available slots', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiaryStructureScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & banner
      expect(find.text('Diary structure'), findsOneWidget);
      expect(find.text('Your daily diary layout'), findsOneWidget);
      expect(
        find.textContaining('Removing a slot never deletes or hides previously logged food'),
        findsOneWidget,
      );

      // Presets
      expect(find.text('Standard (4)'), findsOneWidget);
      expect(find.text('3 Meals'), findsOneWidget);
      expect(find.text('5 Meals'), findsOneWidget);
      expect(find.text('Athlete (6)'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Default 4 active slots
      expect(find.text('ACTIVE SLOTS (4)'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);

      // Available optional slots
      expect(find.text('AVAILABLE OPTIONAL SLOTS'), findsOneWidget);
      expect(find.text('Morning snack'), findsOneWidget);
      expect(find.text('Pre-workout'), findsOneWidget);
    });

    testWidgets('tapping 3 Meals preset updates active slots to 3', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiaryStructureScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('3 Meals'));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE SLOTS (3)'), findsOneWidget);
      // Snacks should now be in available slots
      expect(find.text('AVAILABLE OPTIONAL SLOTS'), findsOneWidget);
    });

    testWidgets('tapping Add button adds an optional slot to active slots', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DiaryStructureScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE SLOTS (4)'), findsOneWidget);

      // Find the Add button for 'Morning snack'
      final addButtons = find.widgetWithText(TextButton, 'Add');
      expect(addButtons, findsWidgets);

      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE SLOTS (5)'), findsOneWidget);
    });
  });
}

class _FixtureRecord implements NutritionHistoricalReadRecord {
  const _FixtureRecord({
    required this.stableId,
    required this.mealCategory,
    required this.displayLabel,
    required this.calories,
  });

  @override
  final String stableId;
  @override
  final String mealCategory;
  @override
  final String displayLabel;
  final double calories;

  @override
  String get userId => 'local-nutrition-user';
  @override
  String get sourceType => 'test';
  @override
  DateTime get loggedAtUtc => DateTime.utc(2026, 9, 1, 8, 30);
  @override
  String get localDate => '2026-09-01';
  @override
  String? get mealGroupId => null;
  @override
  NutrientCompleteness get completeness => _aggregation({
    'energy': _known('energy', calories, NutrientUnit.kilocalorie),
  }).completeness;
  @override
  NutrientAggregationResult get totals => _aggregation({
    'energy': _known('energy', calories, NutrientUnit.kilocalorie),
  });
  @override
  List<NutritionHistoricalReadItem> get items => [
    NutritionHistoricalReadItem(
      stableId: '$stableId-item',
      position: 0,
      sourceType: 'test',
      displayLabel: displayLabel,
      foodId: 'food-1',
      recipeVersionId: null,
      quantity: const NutritionHistoricalQuantity(
        storedAmount: 100,
        storedUnit: 'g',
        quantity: null,
        state: NutritionHistoricalQuantityState.unresolved,
        issues: [],
      ),
      facts: totals.facts,
      issues: const [],
    ),
  ];
  @override
  List<NutritionCompatibilityIssue> get issues => const [];
  @override
  bool get isLegacy => false;
}

NutrientAggregationResult _aggregation(
  Map<String, NutrientFact> facts, {
  List<String> missingNutrientIds = const [],
}) {
  final available = facts.entries
      .where((entry) => entry.value.isAvailable)
      .map((entry) => entry.key)
      .toList();
  final estimated = facts.entries
      .where((entry) => entry.value.status == NutrientFactStatus.estimated)
      .map((entry) => entry.key)
      .toList();
  return NutrientAggregationResult(
    facts: facts,
    completeness: NutrientCompleteness(
      state: missingNutrientIds.isEmpty
          ? NutrientCompletenessState.complete
          : NutrientCompletenessState.partial,
      requestedNutrientIds: [...facts.keys, ...missingNutrientIds],
      availableNutrientIds: available,
      missingNutrientIds: missingNutrientIds,
      estimatedNutrientIds: estimated,
      notApplicableNutrientIds: const [],
      partiallyKnownNutrientIds: const [],
    ),
    sourceLineage: const {},
    factVersionLineage: const {},
  );
}

NutrientFact _known(String id, num amount, NutrientUnit unit) =>
    NutrientFact.known(
      nutrientId: id,
      point: _amount(amount, unit),
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: NutrientSourceType.userEntered,
    );

NutrientAmount _amount(num value, NutrientUnit unit) =>
    NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit);
