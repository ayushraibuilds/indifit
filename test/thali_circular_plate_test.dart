import 'dart:async';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide
        NutritionConsumptionSnapshot,
        NutritionThaliItem,
        NutritionUserConstraint;
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/features/food_log/nutrition_thali_controller.dart';
import 'package:indifit/features/food_log/thali/circular_thali_plate.dart';
import 'package:indifit/features/food_log/thali/thali_builder_screen.dart';
import 'package:indifit/features/food_log/thali/thali_plate_layout.dart';
import 'package:indifit/features/food_log/thali/thali_quick_adjust_hud.dart';



class _TestHarness {
  final AppDatabase db;
  final NutrientRegistry registry;
  final NutritionRecipeRepository recipes;
  final NutritionConsumptionRepository consumption;
  final NutritionThaliRepository repository;
  final String userId;

  _TestHarness._(
    this.db,
    this.registry,
    this.recipes,
    this.consumption,
    this.repository,
    this.userId,
  );

  static Future<_TestHarness> create({WidgetTester? tester}) async {
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    Future<void> doInserts() async {
      await _insertFoodItem(db, 'food-roti', 120, 'Roti (Whole Wheat)', 'roti');
      await _insertFoodItem(db, 'food-dal', 150, 'Dal Tadka', 'dal');
      await _insertFoodItem(db, 'food-rice', 130, 'Steamed Rice', 'rice');
      await _insertFoodItem(db, 'food-curd', 60, 'Fresh Curd', 'curd');
      await _insertFoodItem(db, 'food-sabzi', 80, 'Aloo Gobi', 'sabzi');
    }

    if (tester != null) {
      await tester.runAsync(doInserts);
    } else {
      await doInserts();
    }

    final recipes = NutritionRecipeRepository(db: db);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final repo = NutritionThaliRepository(
      db: db,
      registry: registry,
      recipes: recipes,
      recipeLogging: NutritionRecipeLogCoordinator(
        db: db,
        recipes: recipes,
        calculator: const NutritionCalculationService(),
        consumption: consumption,
        registry: registry,
      ),
      measures: NutritionHouseholdMeasureRepository(db: db),
      constraints: NutritionConstraintRepository(database: db),
      consumption: consumption,
    );
    return _TestHarness._(
      db,
      registry,
      recipes,
      consumption,
      repo,
      kLocalNutritionUserScopeId,
    );
  }

  Future<void> close() => db.close();
}

Future<void> _insertFoodItem(
  AppDatabase db,
  String id,
  double energy,
  String displayName,
  String alias,
) async {
  await db.into(db.nutritionFoods).insert(
        NutritionFoodsCompanion.insert(
          id: id,
          kind: 'canonical',
          displayName: displayName,
          locale: 'en-IN',
          sourceType: 'fixture',
          lifecycle: 'active',
        ),
      );
  await db.into(db.nutritionFoodAliases).insert(
        NutritionFoodAliasesCompanion.insert(
          id: '$id-alias',
          foodId: Value(id),
          alias: alias,
          normalizedAlias: alias.toLowerCase(),
          locale: 'en-IN',
          source: 'canonical',
          isActive: const Value(true),
        ),
      );
  await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-energy-v1',
          foodId: id,
          nutrientId: 'energy',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: Value(energy),
          isCurrent: const Value(true),
        ),
      );
  await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-protein-v1',
          foodId: id,
          nutrientId: 'protein',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: const Value(6.0),
          isCurrent: const Value(true),
        ),
      );
  await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-carb-v1',
          foodId: id,
          nutrientId: 'carbohydrate',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: const Value(25.0),
          isCurrent: const Value(true),
        ),
      );
  await db.into(db.nutritionFoodNutrientFacts).insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-fat-v1',
          foodId: id,
          nutrientId: 'fat',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: const Value(2.0),
          isCurrent: const Value(true),
        ),
      );
}

NutritionThaliItem _buildItem({
  required String id,
  required String displayLabel,
  double amount = 100.0,
  QuantityUnit unit = QuantityUnit.gram,
  int position = 0,
}) {
  return NutritionThaliItem(
    id: id,
    position: position,
    source: NutritionThaliItemSource.food,
    foodId: 'food_$id',
    recipeVersionId: null,
    displayLabel: displayLabel,
    quantity: Quantity.fromNum(amount: amount, unit: unit),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = B05SemanticColors.dark;

  group('1. ThaliDishClassifier', () {
    test('classifies Indian breads into center staple zone', () {
      for (final label in ['Phulka Roti', 'Tandoori Naan', 'Aloo Paratha', 'Poori', 'Chapati']) {
        final placement = ThaliDishClassifier.classify(
          displayLabel: label,
          colors: colors,
        );
        expect(placement.zone, ThaliPlateZone.center);
        expect(placement.category, ThaliDishCategory.stapleBread);
      }
    });

    test('classifies rice and grains into center staple zone', () {
      for (final label in ['Jeera Rice', 'Steamed Chawal', 'Veg Pulao', 'Khichdi', 'Biryani']) {
        final placement = ThaliDishClassifier.classify(
          displayLabel: label,
          colors: colors,
        );
        expect(placement.zone, ThaliPlateZone.center);
        expect(placement.category, ThaliDishCategory.stapleRice);
      }
    });

    test('classifies dals, legumes, and regional lentils into perimeter dal category', () {
      for (final label in ['Dal Tadka', 'Sambar', 'Rasam', 'Kadhi', 'Chole Masala', 'Rajma']) {
        final placement = ThaliDishClassifier.classify(
          displayLabel: label,
          colors: colors,
        );
        expect(placement.zone, ThaliPlateZone.perimeter);
        expect(placement.category, ThaliDishCategory.dal);
      }
    });

    test('classifies regional vegetables into perimeter sabzi category', () {
      for (final label in ['Bhindi Fry', 'Aloo Gobi', 'Beans Poriyal', 'Cabbage Thoran', 'Palak Paneer']) {
        final placement = ThaliDishClassifier.classify(
          displayLabel: label,
          colors: colors,
        );
        expect(placement.zone, ThaliPlateZone.perimeter);
        expect(
          placement.category == ThaliDishCategory.sabzi ||
              placement.category == ThaliDishCategory.curry,
          isTrue,
        );
      }
    });

    test('classifies curds and raitas into perimeter curd category', () {
      for (final label in ['Boondi Raita', 'Fresh Dahi', 'Chaas', 'Curd']) {
        final placement = ThaliDishClassifier.classify(
          displayLabel: label,
          colors: colors,
        );
        expect(placement.zone, ThaliPlateZone.perimeter);
        expect(placement.category, ThaliDishCategory.curd);
      }
    });

    test('classifies South Indian staples into center staple zone', () {
      for (final label in ['Masala Dosa', 'Steamed Idli', 'Onion Uttapam', 'Appam', 'Medu Vada', 'Pesarattu']) {
        final placement = ThaliDishClassifier.classify(
          displayLabel: label,
          colors: colors,
        );
        expect(placement.zone, ThaliPlateZone.center);
        expect(placement.category, ThaliDishCategory.stapleBread);
      }
    });

    test('distinguishes Dal Makhani from Paneer Makhani', () {
      final dalMakhani = ThaliDishClassifier.classify(
        displayLabel: 'Dal Makhani',
        colors: colors,
      );
      expect(dalMakhani.zone, ThaliPlateZone.perimeter);
      expect(dalMakhani.category, ThaliDishCategory.dal);

      final paneerMakhani = ThaliDishClassifier.classify(
        displayLabel: 'Paneer Makhani',
        colors: colors,
      );
      expect(paneerMakhani.zone, ThaliPlateZone.perimeter);
      expect(paneerMakhani.category, ThaliDishCategory.curry);
      expect(paneerMakhani.category != ThaliDishCategory.dal, isTrue);

      final chickenMakhani = ThaliDishClassifier.classify(
        displayLabel: 'Butter Chicken Makhani',
        colors: colors,
      );
      expect(chickenMakhani.zone, ThaliPlateZone.perimeter);
      expect(chickenMakhani.category, ThaliDishCategory.curry);
    });

    test('safely falls back to side for unrecognized / custom foods', () {
      final placement = ThaliDishClassifier.classify(
        displayLabel: 'Grandma Special Mix #4',
        colors: colors,
      );
      expect(placement.zone, ThaliPlateZone.perimeter);
      expect(placement.category, ThaliDishCategory.side);
      expect(placement.categoryLabel, 'Side Dish');
    });
  });

  group('2. ThaliPlateLayoutEngine', () {
    test('separates center staple and distributes perimeter items', () {
      final items = [
        _buildItem(id: '1', displayLabel: 'Roti'),
        _buildItem(id: '2', displayLabel: 'Dal Tadka'),
        _buildItem(id: '3', displayLabel: 'Aloo Gobi'),
        _buildItem(id: '4', displayLabel: 'Curd'),
      ];

      final layout = ThaliPlateLayoutEngine.computeLayout(
        items: items,
        previews: [],
        colors: colors,
        showAddSlot: true,
      );

      expect(layout.centerStaples.length, 1);
      expect(layout.centerStaples.first.item.displayLabel, 'Roti');

      // 3 perimeter items + 1 add slot = 4 slots
      expect(layout.perimeterSlots.length, 4);
      expect(layout.perimeterSlots.last, isA<ThaliAddSlot>());
    });

    test('handles overflow when perimeter items exceed 6 slots', () {
      final items = [
        _buildItem(id: '1', displayLabel: 'Roti'), // Center
        _buildItem(id: '2', displayLabel: 'Dal Tadka'),
        _buildItem(id: '3', displayLabel: 'Aloo Gobi'),
        _buildItem(id: '4', displayLabel: 'Curd'),
        _buildItem(id: '5', displayLabel: 'Paneer Masala'),
        _buildItem(id: '6', displayLabel: 'Mint Chutney'),
        _buildItem(id: '7', displayLabel: 'Gulab Jamun'),
        _buildItem(id: '8', displayLabel: 'Papad'),
      ];

      final layout = ThaliPlateLayoutEngine.computeLayout(
        items: items,
        previews: [],
        colors: colors,
      );

      expect(layout.centerStaples.length, 1);
      // 5 visible items + 1 overflow slot = 6 perimeter slots
      expect(layout.perimeterSlots.length, 6);
      expect(layout.perimeterSlots.last, isA<ThaliOverflowSlot>());
      final overflow = layout.perimeterSlots.last as ThaliOverflowSlot;
      // 7 perimeter items total - 5 visible = 2 overflow
      expect(overflow.overflowCount, 2);
    });
  });

  group('3. CircularThaliPlate & ThaliQuickAdjustHud Unit Tests', () {
    testWidgets('renders plate, perimeter katoris, and invokes selection callback', (tester) async {
      final items = [
        _buildItem(id: 'roti_1', displayLabel: 'Roti'),
        _buildItem(id: 'dal_1', displayLabel: 'Dal'),
      ];

      String? selectedId;
      bool addTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                height: 350,
                child: CircularThaliPlate(
                  items: items,
                  previews: const [],
                  selectedItemId: selectedId,
                  onSelectItem: (id) => selectedId = id,
                  onAddDish: () => addTapped = true,
                  onViewAllDishes: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify staple and katori keys
      expect(find.byKey(const Key('thali_plate_staple_roti_1')), findsOneWidget);
      expect(find.byKey(const Key('thali_plate_katori_dal_1')), findsOneWidget);
      expect(find.byKey(const Key('thali_plate_add_slot')), findsOneWidget);

      // Tap katori
      await tester.tap(find.byKey(const Key('thali_plate_katori_dal_1')));
      expect(selectedId, 'dal_1');

      // Tap add slot
      await tester.tap(find.byKey(const Key('thali_plate_add_slot')));
      expect(addTapped, isTrue);
    });

    testWidgets('ThaliQuickAdjustHud handles increment, decrement, and remove', (tester) async {
      final item = _buildItem(id: 'dal_1', displayLabel: 'Yellow Dal Tadka', amount: 1.0);

      int incrementCount = 0;
      int decrementCount = 0;
      bool removeCalled = false;
      bool closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ThaliQuickAdjustHud(
              item: item,
              preview: null,
              onIncrement: () => incrementCount++,
              onDecrement: () => decrementCount++,
              onRemove: () => removeCalled = true,
              onReplace: () {},
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('thali_quick_hud')), findsOneWidget);
      expect(find.text('Yellow Dal Tadka'), findsOneWidget);

      // Steppers
      await tester.tap(find.byKey(const Key('thali_quick_hud_increment')));
      expect(incrementCount, 1);

      await tester.tap(find.byKey(const Key('thali_quick_hud_decrement')));
      expect(decrementCount, 1);

      // Remove
      await tester.tap(find.byKey(const Key('thali_quick_hud_remove')));
      expect(removeCalled, isTrue);

      // Close
      await tester.tap(find.byKey(const Key('thali_quick_hud_close')));
      expect(closeCalled, isTrue);
    });

    testWidgets('Macro ring painter paints without error for zero calories and partial state', (tester) async {
      final items = [_buildItem(id: '1', displayLabel: 'Water')];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: CircularThaliPlate(
              items: items,
              previews: const [],
              preview: null, // 0 macro facts
              onSelectItem: (_) {},
              onAddDish: () {},
              onViewAllDishes: () {},
            ),
          ),
        ),
      );

      // Verify no crash on zero macros
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders SizedBox.shrink when available size is smaller than 140px threshold', (tester) async {
      final items = [_buildItem(id: '1', displayLabel: 'Roti')];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: CircularThaliPlate(
                  items: items,
                  previews: const [],
                  onSelectItem: (_) {},
                  onAddDish: () {},
                  onViewAllDishes: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularThaliPlate), findsOneWidget);
      expect(find.byKey(const Key('thali_plate_staple_1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('provides accessibility Semantics for staple, katori, and add slots', (tester) async {
      final items = [
        _buildItem(id: 'roti_1', displayLabel: 'Roti'),
        _buildItem(id: 'dal_1', displayLabel: 'Dal'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                height: 350,
                child: CircularThaliPlate(
                  items: items,
                  previews: const [],
                  selectedItemId: 'dal_1',
                  onSelectItem: (_) {},
                  onAddDish: () {},
                  onViewAllDishes: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final semantics = tester.ensureSemantics();
      try {
        final stapleSemantics = tester.getSemantics(find.byKey(const Key('thali_plate_staple_roti_1')));
        expect(stapleSemantics.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(stapleSemantics.getSemanticsData().label, contains('Roti'));

        final katoriSemantics = tester.getSemantics(find.byKey(const Key('thali_plate_katori_dal_1')));
        expect(katoriSemantics.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(katoriSemantics.getSemanticsData().flagsCollection.isSelected.name, 'isTrue');
        expect(katoriSemantics.getSemanticsData().label, contains('Dal'));

        final addSemantics = tester.getSemantics(find.byKey(const Key('thali_plate_add_slot')));
        expect(addSemantics.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(addSemantics.getSemanticsData().label, contains('Add dish to platter'));
      } finally {
        semantics.dispose();
      }
    });
  });

  group('4. ThaliBuilderScreen Dual-View Integration', () {
    testWidgets('supports toggling between Plate and List views and displays HUD on katori tap', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _TestHarness.create(tester: tester);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      final controller = NutritionThaliController(
        repository: Future.value(harness.repository),
        userId: harness.userId,
        mealCategory: 'lunch',
      );
      await tester.runAsync(controller.initialize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(harness.db),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'Asia/Kolkata'),
            ),
            nutritionThaliRepositoryProvider.overrideWith(
              (ref) async => harness.repository,
            ),
            nutritionThaliControllerProvider('lunch').overrideWith(
              (ref) => controller,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ThaliBuilderScreen(mealCategory: 'lunch'),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));

      // Initial empty state
      expect(find.text('Your Thali Plate is Empty'), findsOneWidget);
      expect(find.byKey(const Key('thali_add_item_empty_button')), findsOneWidget);

      // Load North Indian Classic preset
      await tester.tap(find.byKey(const Key('thali_preset_north_indian_classic')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Plate view is default: CircularThaliPlate and items list are both mounted
      expect(find.byType(CircularThaliPlate), findsOneWidget);
      expect(find.byKey(const Key('thali_items_list')), findsOneWidget);
      expect(find.byKey(const Key('thali_view_mode_plate')), findsOneWidget);
      expect(find.byKey(const Key('thali_view_mode_list')), findsOneWidget);

      // 2. Tap a katori on the circular plate
      final dalItem = controller.state.draft!.items.firstWhere(
        (i) => i.displayLabel?.contains('Dal') ?? false,
      );
      final katoriFinder = find.byKey(Key('thali_plate_katori_${dalItem.id}'));
      expect(katoriFinder, findsOneWidget);
      await tester.tap(katoriFinder);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));

      // 3. HUD should now be visible
      expect(find.byKey(const Key('thali_quick_hud')), findsOneWidget);
      expect(find.byKey(const Key('thali_quick_hud_increment')), findsOneWidget);

      // 4. Tap increment on HUD
      await tester.tap(find.byKey(const Key('thali_quick_hud_increment')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 200));

      // 5. Switch to List view
      await tester.tap(find.byKey(const Key('thali_view_mode_list')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 200));

      // In List view, CircularThaliPlate is hidden, list remains
      expect(find.byType(CircularThaliPlate), findsNothing);
      expect(find.byKey(const Key('thali_items_list')), findsOneWidget);

      // 6. Switch back to Plate view
      await tester.tap(find.byKey(const Key('thali_view_mode_plate')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularThaliPlate), findsOneWidget);
    });

    testWidgets('supports replacing dish via HUD and component picker sheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _TestHarness.create(tester: tester);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        unawaited(harness.close());
      });

      final controller = NutritionThaliController(
        repository: Future.value(harness.repository),
        userId: harness.userId,
        mealCategory: 'lunch',
      );
      await tester.runAsync(controller.initialize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(harness.db),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'Asia/Kolkata'),
            ),
            nutritionThaliRepositoryProvider.overrideWith(
              (ref) async => harness.repository,
            ),
            nutritionThaliControllerProvider('lunch').overrideWith(
              (ref) => controller,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ThaliBuilderScreen(mealCategory: 'lunch'),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));

      // Load North Indian Classic preset
      await tester.tap(find.byKey(const Key('thali_preset_north_indian_classic')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));

      // Select Dal item katori
      final dalItem = controller.state.draft!.items.firstWhere(
        (i) => i.displayLabel?.contains('Dal') ?? false,
      );
      await tester.tap(find.byKey(Key('thali_plate_katori_${dalItem.id}')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('thali_quick_hud')), findsOneWidget);
      expect(find.byKey(const Key('thali_quick_hud_replace')), findsOneWidget);

      // Tap replace
      await tester.tap(find.byKey(const Key('thali_quick_hud_replace')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom sheet should display replace title
      expect(find.text('Replace Dish in Thali'), findsOneWidget);

      // Search for 'Steamed Rice'
      await tester.enterText(find.byKey(const Key('thali_search_input')), 'Steamed Rice');
      await tester.runAsync(() => controller.search('Steamed Rice'));
      await tester.pump();

      // Select food item from search results
      final riceOptionFinder = find.byKey(const Key('thali_search_food_item_food-rice'));
      expect(riceOptionFinder, findsOneWidget);
      await tester.tap(riceOptionFinder);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 200));

      // Portion card is visible with 'Replace on Plate' button
      expect(find.text('Replace on Plate'), findsOneWidget);

      // Confirm replace
      await tester.tap(find.byKey(const Key('thali_add_selected_item_button')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();

      // Old Dal item is gone, Steamed Rice item is present
      expect(find.byKey(Key('thali_plate_katori_${dalItem.id}')), findsNothing);
      expect(
        controller.state.draft!.items.any((i) => i.displayLabel == 'Steamed Rice'),
        isTrue,
      );
      // Switch to List view to view all item cards
      await tester.tap(find.byKey(const Key('thali_view_mode_list')));
      await tester.pumpAndSettle();
      expect(find.text('Steamed Rice'), findsOneWidget);
      // HUD is dismissed
      expect(find.byKey(const Key('thali_quick_hud')), findsNothing);
    });
  });
}
