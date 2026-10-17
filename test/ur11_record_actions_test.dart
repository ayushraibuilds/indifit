import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/food_log/widgets/food_diary_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UR-11 / UR-51: every logged record on the meal page has Edit and Delete,
/// through one entry point, and Delete can be undone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  late RealCatalogue catalogue;
  late LoggedRecords logged;

  Future<void> pumpMeal(
    WidgetTester tester,
    String meal, {
    double width = 402,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    catalogue = (await tester.runAsync(RealCatalogue.open))!;
    addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
    logged = (await tester.runAsync(() => LoggedRecords.log(catalogue)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: loggedRecordsOverrides(catalogue),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: FoodMealDetailScreen(
            mealType: meal,
            selectedDate: DateTime(2026, 10, 8),
          ),
        ),
      ),
    );
    await settleLoggedRecords(tester);
  }

  Finder actionsFor(String sourceType) {
    final record = logged.bySource[sourceType]!;
    final label = record.items.length == 1 && sourceType == 'direct_food'
        ? record.items.single.displayLabel!
        : NutritionCanonicalSnapshotReadModel(record).displayLabel;
    return find.bySemanticsLabel('Actions for $label');
  }

  Future<int> liveCount() async =>
      (await NutritionReadModelRepository(
            db: catalogue.db,
            registry: catalogue.registry,
            canonicalRepository: catalogue.consumption,
            legacyUserId: kLocalNutritionUserScopeId,
          ).dailyTotals(
            userId: kLocalNutritionUserScopeId,
            localDate: loggedRecordsDate,
          ))
          .records
          .length;

  for (final (meal, source) in [
    ('lunch', 'direct_food'),
    ('lunch', 'quick_add'),
    ('lunch', 'thali'),
    ('lunch', 'recipe'),
    ('lunch', 'estimate'),
    ('dinner', 'repeat'),
  ]) {
    testWidgets('a $source row offers Edit and Delete', (tester) async {
      await pumpMeal(tester, meal);
      final actions = actionsFor(source);
      expect(actions, findsOneWidget);
      await tester.tap(actions);
      await settleLoggedRecords(tester);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('Edit'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('Delete'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('deleting a thali from its sheet can be undone', (tester) async {
    await pumpMeal(tester, 'lunch');
    final before = (await tester.runAsync(liveCount))!;
    await tester.tap(actionsFor('thali'));
    await settleLoggedRecords(tester);
    await tester.tap(find.text('Delete entry'));
    await settleLoggedRecords(tester, rounds: 8);
    expect(actionsFor('thali'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settleLoggedRecords(tester);
    expect(actionsFor('thali'), findsOneWidget);
    // Past the Undo window nothing was removed.
    await tester.pump(const Duration(seconds: 6));
    await settleLoggedRecords(tester);
    expect((await tester.runAsync(liveCount))!, before);
  });

  testWidgets('swiping a recipe away removes it after the Undo window', (
    tester,
  ) async {
    await pumpMeal(tester, 'lunch');
    final before = (await tester.runAsync(liveCount))!;
    await tester.drag(actionsFor('recipe'), const Offset(-600, 0));
    await settleLoggedRecords(tester, rounds: 8);
    expect(actionsFor('recipe'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await settleLoggedRecords(tester, rounds: 20);
    expect((await tester.runAsync(liveCount))!, before - 1);
    expect(actionsFor('recipe'), findsNothing);
  });

  testWidgets('swiping an AI estimate away can be undone', (tester) async {
    await pumpMeal(tester, 'lunch');
    await tester.drag(actionsFor('estimate'), const Offset(-600, 0));
    await settleLoggedRecords(tester, rounds: 8);
    expect(actionsFor('estimate'), findsNothing);
    await tester.tap(find.text('Undo'));
    await settleLoggedRecords(tester);
    expect(actionsFor('estimate'), findsOneWidget);
  });

  testWidgets('editing a quick add pre-fills it and replaces the entry', (
    tester,
  ) async {
    // Wide enough for the sheet's date field under the test font.
    await pumpMeal(tester, 'lunch', width: 700);
    final before = (await tester.runAsync(liveCount))!;
    await tester.tap(actionsFor('quick_add'));
    await settleLoggedRecords(tester);
    await tester.tap(find.text('Edit entry'));
    await settleLoggedRecords(tester);
    expect(find.widgetWithText(TextField, 'Office samosa'), findsOneWidget);
    expect(find.widgetWithText(TextField, '250'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '250'), '300');
    await tester.ensureVisible(find.text('Log calories'));
    await tester.tap(find.text('Log calories'));
    await settleLoggedRecords(tester, rounds: 12);
    expect((await tester.runAsync(liveCount))!, before);
    final lunch = (await tester.runAsync(
      () =>
          NutritionReadModelRepository(
            db: catalogue.db,
            registry: catalogue.registry,
            canonicalRepository: catalogue.consumption,
            legacyUserId: kLocalNutritionUserScopeId,
          ).dailyTotals(
            userId: kLocalNutritionUserScopeId,
            localDate: loggedRecordsDate,
          ),
    ))!.records.where((record) => record.displayLabel == 'Office samosa');
    expect(lunch, hasLength(1));
    expect(lunch.single.totals.facts['energy']!.point!.value.toString(), '300');
  });
}
