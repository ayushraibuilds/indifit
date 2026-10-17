import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UR-02: "3 roti" logs 3 pieces from the "+" and opens the portion sheet
/// at 3; UR-03: a relaxed search says so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Online nutrition off: the test never reaches the network.
  setUp(
    () => SharedPreferences.setMockInitialValues({
      PrivacyPolicyNotifier.prefOnlineNutritionAllowed: false,
    }),
  );

  late RealCatalogue catalogue;

  Future<void> search(WidgetTester tester, String query) async {
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
          home: FoodSearchScreen(
            mealType: 'lunch',
            selectedDate: DateTime(2026, 10, 8),
          ),
        ),
      ),
    );
    await settleLoggedRecords(tester);
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump(const Duration(milliseconds: 800));
    await settleLoggedRecords(tester, rounds: 20);
  }

  Finder rotiAdd() =>
      find.bySemanticsLabel(RegExp(r'^Add 3 pieces Whole Wheat Roti'));

  testWidgets('the "+" names and logs the typed amount', (tester) async {
    await search(tester, '3 roti');
    expect(rotiAdd(), findsOneWidget);
    await tester.tap(rotiAdd());
    await settleLoggedRecords(tester, rounds: 12);
    expect(
      find.textContaining(
        RegExp(
          r'^Added 3 pieces Whole Wheat Roti / Chapati · \d+ kcal to Lunch',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the portion sheet opens at the typed amount', (tester) async {
    await search(tester, '3 roti');
    await tester.tap(find.text('Whole Wheat Roti / Chapati').first);
    await settleLoggedRecords(tester, rounds: 12);
    expect(find.text('Add to Lunch'), findsOneWidget);
    final amount = tester.widget<TextField>(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          )
          .first,
    );
    expect(amount.controller!.text, '3');
  });

  testWidgets('a relaxed search says what it searched', (tester) async {
    await search(tester, 'cheese dosa');
    expect(find.text('No exact match'), findsOneWidget);
    expect(find.text('Showing results for “dosa”.'), findsOneWidget);
    expect(find.textContaining('Dosa'), findsWidgets);
  });
}
