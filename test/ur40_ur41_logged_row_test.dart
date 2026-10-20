import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/dashboard/widgets/today_header_widgets.dart';
import 'package:indifit/features/dashboard/widgets/today_nutrition_widgets.dart';
import 'package:indifit/features/food_log/food_diary_screen.dart';
import 'package:indifit/features/food_log/widgets/logged_food_row.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UR-40 one logged-food row, UR-41 the diary with Today's header pieces.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late RealCatalogue catalogue;
  late LoggedRecords logged;

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(402, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    catalogue = (await tester.runAsync(RealCatalogue.open))!;
    addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
    logged = (await tester.runAsync(() => LoggedRecords.log(catalogue)))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: loggedRecordsOverrides(catalogue),
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      ),
    );
    await settleLoggedRecords(tester);
  }

  testWidgets('one row for every source type', (tester) async {
    await pump(tester, const SizedBox.shrink());
    final actions = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: loggedRecordsOverrides(catalogue),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListView(
              children: [
                for (final entry in logged.bySource.entries)
                  LoggedFoodRow(
                    record: NutritionCanonicalSnapshotReadModel(entry.value),
                    onActions: () => actions.add(entry.key),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await settleLoggedRecords(tester);
    expect(
      logged.bySource.keys,
      containsAll([
        'direct_food',
        'thali',
        'recipe',
        'quick_add',
        'estimate',
        'repeat',
      ]),
    );
    expect(find.byType(LoggedFoodRow), findsNWidgets(logged.bySource.length));
    for (final entry in logged.bySource.entries) {
      final record = NutritionCanonicalSnapshotReadModel(entry.value);
      expect(find.text(record.displayLabel), findsWidgets, reason: entry.key);
      final kcal = record.totals.facts['energy']?.point?.value;
      if (kcal != null) {
        expect(
          find.textContaining('${kcal.format(decimalPlaces: 0)} kcal'),
          findsWidgets,
          reason: entry.key,
        );
      }
    }
    // "…" is the record-actions entry point.
    await tester.tap(
      find.bySemanticsLabel(RegExp('Actions for Office samosa')).first,
    );
    expect(actions, contains('quick_add'));
  });

  testWidgets('a thali row expands to its items and collapses', (tester) async {
    await pump(tester, const SizedBox.shrink());
    final thali = NutritionCanonicalSnapshotReadModel(
      logged.bySource['thali']!,
    );
    expect(thali.items.length, greaterThan(1));
    await tester.pumpWidget(
      ProviderScope(
        overrides: loggedRecordsOverrides(catalogue),
        child: MaterialApp(
          home: Scaffold(
            body: LoggedFoodRow(record: thali, onActions: () {}),
          ),
        ),
      ),
    );
    await settleLoggedRecords(tester);
    final firstItem = thali.items.first.displayLabel!.trim();
    expect(find.textContaining('${thali.items.length} items'), findsWidgets);
    expect(find.byKey(ValueKey('logged_food_part_$firstItem')), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pump();
    for (final item in thali.items) {
      expect(
        find.byKey(ValueKey('logged_food_part_${item.displayLabel!.trim()}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byIcon(Icons.expand_less_rounded));
    await tester.pump();
    expect(find.byKey(ValueKey('logged_food_part_$firstItem')), findsNothing);
  });

  testWidgets(
    "the diary uses Today's week strip, and its totals match the day",
    (tester) async {
      await pump(
        tester,
        FoodDiaryScreen(
          selectedDate: DateTime(2026, 10, 8),
          today: DateTime(2026, 10, 8),
        ),
      );
      expect(find.byType(TodayWeekStrip), findsOneWidget);
      expect(find.byType(MacroComparison), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Logged food shows as rows in the diary too.
      expect(find.byType(LoggedFoodRow), findsWidgets);

      final day = (await tester.runAsync(
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
      ))!;
      // The same day total Today's hero reads (UR-41).
      final total = day.totals.facts['energy']!.point!.value.asDouble;
      expect(
        find.textContaining('${NumberFormat('#,##0').format(total)} kcal'),
        findsWidgets,
      );
    },
  );
}
