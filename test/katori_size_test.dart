import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/catalog/catalogue_quantity_resolver.dart';
import 'package:indifit/data/catalog/katori_size.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/features/food_log/katori_size_step.dart';
import 'package:indifit/features/nutrition_ai/meal_item_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_catalogue.dart';

/// The katori calibration step: "1 katori" means the person's own katori
/// once they've picked its size, everywhere the catalogue counts katori.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dal = 'Toor Dal / Yellow Dal Tadka';
  const curd = 'Plain Curd / Dahi (Cow Milk)';

  late RealCatalogue catalogue;
  setUp(() async => catalogue = await RealCatalogue.open());
  tearDown(() => catalogue.close());

  Future<void> chooseKatori(double millilitres) async {
    final repository = NutritionHouseholdMeasureRepository(db: catalogue.db);
    // One "My katori", recalibrated, as the step saves it.
    final vessels = await repository.listVessels(
      userId: kLocalNutritionUserScopeId,
    );
    final vessel =
        vessels
            .where((vessel) => vessel.vesselType == kMyKatoriVesselType)
            .firstOrNull ??
        await repository.createVessel(
          userId: kLocalNutritionUserScopeId,
          displayName: 'My katori',
          vesselType: kMyKatoriVesselType,
        );
    await repository.addCalibration(
      userId: kLocalNutritionUserScopeId,
      vesselId: vessel.id,
      volume: Quantity.fromNum(
        amount: millilitres,
        unit: QuantityUnit.millilitre,
      ),
      method: 'size_choice',
    );
  }

  Future<CatalogueFoodMeasure> measure(String name) async =>
      (await CatalogueQuantityResolver(
        catalogue.db,
      ).measureFor(await catalogue.foodId(name)))!;

  double servingsFor(CatalogueFoodMeasure m, double katori) => m
      .toFactBasis(
        m.householdQuantity('katori', QuantityAmount.fromNum(katori)),
      )
      .amount
      .asDouble;

  test('without a choice, a katori is the standard one', () async {
    expect(await readMyKatoriMillilitres(catalogue.db), isNull);
    final m = await measure(dal);
    expect(m.katoriScale, 1);
    expect(m.unitsPerServing!.asDouble, 1);
    expect(servingsFor(m, 1), 1);
  });

  test('a large katori holds a third more dal', () async {
    await chooseKatori(200);
    expect(await readMyKatoriMillilitres(catalogue.db), 200);

    final m = await measure(dal);
    expect(m.katoriScale, closeTo(1.3333, 0.0001));
    expect(m.unitsPerServing!.asDouble, 0.75);
    expect(servingsFor(m, 1), closeTo(1.3333, 0.001));
    // Grams per catalogue serving are unchanged: a serving is still 150 g.
    expect(m.gramsPerServing!.asDouble, 150);
  });

  test('the newest choice wins', () async {
    await chooseKatori(200);
    await chooseKatori(100);
    final m = await measure(dal);
    expect(servingsFor(m, 1), closeTo(0.6667, 0.001));
  });

  test('AI portions: katori is yours, bowl and plate stay fixed', () async {
    await chooseKatori(200);
    final dalOption = (await catalogue.catalog.getOption(
      await catalogue.foodId(dal),
    ))!;

    double servings(double amount, String unit) => PortionMapping.map(
      amount: amount,
      unit: unit,
      option: dalOption,
    ).quantity.amount.asDouble;

    expect(servings(1, 'katori'), closeTo(1.33, 0.01));
    // The app's bowl is 300 g, two standard katori, whatever your katori.
    expect(servings(1, 'bowl'), 2);
    expect(servings(1, 'plate'), 2);

    final curdOption = (await catalogue.catalog.getOption(
      await catalogue.foodId(curd),
    ))!;
    final katoriCurd = PortionMapping.map(
      amount: 1,
      unit: 'katori',
      option: curdOption,
    );
    expect(katoriCurd.quantity.unit, QuantityUnit.gram);
    expect(katoriCurd.quantity.amount.asDouble, 200);
  });

  group('the step', () {
    Future<void> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(catalogue.db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: Scaffold(body: KatoriSizePromptCard()),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    testWidgets('picking Large saves it and the question goes away', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('How big is your katori?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('katori_size_open')));
      await tester.pumpAndSettle();
      expect(find.text('Which katori looks like yours?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('katori_size_200')));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(
        await tester.runAsync(() => readMyKatoriMillilitres(catalogue.db)),
        200,
      );
      expect(find.byKey(const Key('katori_size_prompt')), findsNothing);
    });

    testWidgets('"Not now" hides it and remembers', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('katori_size_not_now')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(find.byKey(const Key('katori_size_prompt')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kKatoriPromptDismissedKey), isTrue);
      expect(
        await tester.runAsync(() => readMyKatoriMillilitres(catalogue.db)),
        isNull,
      );
    });
  });
}
