import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UR-13: search stays open after an add, with a meal bar that sums the
/// visit and offers Undo per item. UR-14: the "+" says what it adds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({
      PrivacyPolicyNotifier.prefOnlineNutritionAllowed: false,
    }),
  );

  late RealCatalogue catalogue;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    catalogue = (await tester.runAsync(RealCatalogue.open))!;
    addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...loggedRecordsOverrides(catalogue),
          foodRepositoryProvider.overrideWithValue(
            FoodRepository(catalogue.db),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (_) => FoodSearchScreen(
                      mealType: 'lunch',
                      selectedDate: DateTime(2026, 10, 8),
                    ),
                  ),
                ),
                child: const Text('Diary'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Diary'));
    await settleLoggedRecords(tester);
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump(const Duration(milliseconds: 800));
    await settleLoggedRecords(tester, rounds: 20);
  }

  /// Logged records on the day, as the diary reads them (undone ones
  /// drop out).
  Future<int> loggedCount(WidgetTester tester) async => (await tester.runAsync(
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
  ))!.records.length;

  Finder bar() => find.byKey(const ValueKey('food_search_meal_bar'));

  int barKcal(WidgetTester tester) {
    final text = tester
        .widgetList<Text>(
          find.descendant(of: bar(), matching: find.byType(Text)),
        )
        .map((widget) => widget.data ?? '')
        .firstWhere((data) => data.startsWith('Lunch ·'));
    return int.parse(RegExp(r'(\d+) kcal').firstMatch(text)!.group(1)!);
  }

  testWidgets('the "+" names its amount (UR-14)', (tester) async {
    await open(tester);
    await search(tester, 'poha');
    expect(find.bySemanticsLabel(RegExp(r'^Add 1 katori Poha')), findsWidgets);
    expect(find.text('1 katori'), findsWidgets);
  });

  testWidgets('two adds stay in search and sum in the bar', (tester) async {
    await open(tester);
    expect(bar(), findsNothing);

    await search(tester, 'poha');
    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^Add 1 katori Poha')).first,
    );
    await settleLoggedRecords(tester, rounds: 12);
    expect(find.text('Log lunch'), findsOneWidget); // still in search
    expect(find.textContaining('Lunch · 1 item · 230 kcal'), findsOneWidget);

    await search(tester, 'roti');
    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^Add 1 piece Whole Wheat Roti')).first,
    );
    await settleLoggedRecords(tester, rounds: 12);
    expect(find.textContaining('Lunch · 2 items'), findsOneWidget);
    expect(barKcal(tester), greaterThan(230));
    expect(await loggedCount(tester), 2);
  });

  // The toast says what the "+" said (UR-14, UR-50): same amount, same unit.
  for (final (query, food) in [
    ('poha', 'Poha'),
    ('boiled egg', 'Boiled Egg'),
    ('milk', 'Milk'),
  ]) {
    testWidgets('the toast repeats the "+" amount for $query', (tester) async {
      await open(tester);
      await search(tester, query);
      final add = find.bySemanticsLabel(
        RegExp('^Add .*$food', caseSensitive: false),
      );
      expect(add, findsWidgets);
      final label = tester.getSemantics(add.first).label;
      // "Add 1 katori Poha …" -> "1 katori"
      final amount = RegExp(
        r'^Add (\d+(?:\.\d)? \S+)',
      ).firstMatch(label)!.group(1)!;
      await tester.tap(add.first);
      await settleLoggedRecords(tester, rounds: 12);
      final toast = find.byType(SnackBar);
      expect(toast, findsOneWidget);
      expect(
        find.descendant(
          of: toast,
          matching: find.textContaining('Added $amount '),
        ),
        findsOneWidget,
        reason: 'button said "$label"',
      );
      expect(
        find.descendant(of: toast, matching: find.textContaining('1 serving')),
        findsNothing,
      );
    });
  }

  testWidgets('the portion sheet keeps search open, with its confirmation', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'poha');
    await tester.tap(find.text('Poha (Flattened Rice)').first);
    await settleLoggedRecords(tester, rounds: 12);
    await tester.tap(find.text('Add to Lunch'));
    await settleLoggedRecords(tester, rounds: 12);

    expect(find.text('Log lunch'), findsOneWidget);
    expect(find.textContaining('Lunch · 1 item'), findsOneWidget);
    // Wave 1's confirmation with Undo is unchanged.
    expect(
      find.textContaining(RegExp(r'^Added .*Poha .* to Lunch$')),
      findsOneWidget,
    );
    await tester.tap(find.text('Undo'));
    await settleLoggedRecords(tester, rounds: 12);
    expect(bar(), findsNothing);
    expect(await loggedCount(tester), 0);
  });

  testWidgets('Undo from the bar removes that item', (tester) async {
    await open(tester);
    await search(tester, 'poha');
    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^Add 1 katori Poha')).first,
    );
    await settleLoggedRecords(tester, rounds: 12);
    await search(tester, 'roti');
    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^Add 1 piece Whole Wheat Roti')).first,
    );
    await settleLoggedRecords(tester, rounds: 12);
    expect(await loggedCount(tester), 2);

    await tester.tap(
      find.descendant(of: bar(), matching: find.byType(InkWell)).first,
    );
    await settleLoggedRecords(tester, rounds: 8);
    expect(find.textContaining('Poha'), findsWidgets);
    await tester.tap(
      find
          .descendant(of: find.byType(BottomSheet), matching: find.text('Undo'))
          .first,
    );
    await settleLoggedRecords(tester, rounds: 12);

    expect(await loggedCount(tester), 1);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.textContaining('1 item'),
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(300, 40)); // close the sheet
    await settleLoggedRecords(tester, rounds: 8);
    expect(find.textContaining('Lunch · 1 item'), findsOneWidget);
  });

  testWidgets('Done goes back to where search was opened', (tester) async {
    await open(tester);
    await search(tester, 'poha');
    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^Add 1 katori Poha')).first,
    );
    await settleLoggedRecords(tester, rounds: 12);
    await tester.tap(find.byKey(const ValueKey('food_search_meal_bar_done')));
    await settleLoggedRecords(tester, rounds: 8);
    expect(find.text('Diary'), findsOneWidget);
    expect(find.text('Log lunch'), findsNothing);
  });
}
