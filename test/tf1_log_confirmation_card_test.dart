import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/widgets/indi_fit_feedback.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/food_log/log_confirmation.dart';
import 'package:indifit/features/food_log/widgets/meal_icon_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// TF-1 (UR-42): one raised feedback card for every success and Undo toast,
/// and a food-log card that says what changed on the day.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => SharedPreferences.setMockInitialValues({
      PrivacyPolicyNotifier.prefOnlineNutritionAllowed: false,
    }),
  );

  Finder card() => find.byKey(const ValueKey('indifit_feedback_card'));

  group('contrast (AA)', () {
    for (final (name, colors) in [
      ('dark', B05SemanticColors.dark),
      ('light', B05SemanticColors.light),
    ]) {
      test('$name: text ≥ 4.5:1 on the card, edge ≥ 3:1 on the page', () {
        for (final surface in [colors.raised, colors.raisedEnd]) {
          expect(_contrast(colors.textPrimary, surface), greaterThan(4.5));
          expect(_contrast(colors.textSecondary, surface), greaterThan(4.5));
          // Undo is text in the action colour.
          expect(_contrast(colors.action, surface), greaterThan(4.5));
        }
        expect(_contrast(colors.action, colors.page), greaterThan(3));
      });
    }
  });

  group("the day's change line", () {
    test('kcal left after the write, and the protein it added', () {
      expect(
        loggedDayChangeLine(
          dayKcal: 154,
          calorieTargetKcal: 2000,
          addedProteinG: 8,
        ),
        '1,846 kcal left · +8 g protein',
      );
      expect(
        loggedDayChangeLine(dayKcal: 2100, calorieTargetKcal: 2000),
        '100 kcal over',
      );
      expect(loggedDayChangeLine(addedProteinG: 3.4), '+3.4 g protein');
      expect(loggedDayChangeLine(dayKcal: 500), isNull);
      expect(loggedDayChangeLine(addedProteinG: 0), isNull);
    });
  });

  group('the card', () {
    Future<void> pumpHost(
      WidgetTester tester, {
      required ThemeData theme,
      required String message,
      bool reduceMotion = false,
      double textScale = 1,
      VoidCallback? onUndo,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              key: const ValueKey('tab_bar'),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Today'),
                NavigationDestination(icon: Icon(Icons.list), label: 'Food'),
              ],
            ),
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showIndiFitUndoFeedback(
                    context,
                    message: message,
                    duration: const Duration(seconds: 4),
                    detail: Future.value('1,846 kcal left · +8 g protein'),
                    onUndo: onUndo ?? () {},
                  ),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
    }

    for (final (name, theme) in [
      ('dark', AppTheme.darkTheme),
      ('light', AppTheme.lightTheme),
    ]) {
      testWidgets('$name: raised, 1 pt action edge, card radius', (
        tester,
      ) async {
        await pumpHost(tester, theme: theme, message: 'Saved');
        await tester.pumpAndSettle();
        final colors = theme.extension<B05SemanticColors>()!;
        final decoration =
            tester.widget<DecoratedBox>(card()).decoration as ShapeDecoration;
        final shape = decoration.shape as dynamic;
        expect(shape.side.color, colors.action);
        expect(shape.side.width, 1);
        expect(decoration.gradient!.colors, [colors.raised, colors.raisedEnd]);
        expect(decoration.shadows!.single.color, colors.raisedShadow);
        expect(find.text('1,846 kcal left · +8 g protein'), findsOneWidget);
      });
    }

    testWidgets(
      'sits above the tab bar, Undo runs and closes it, gone in 4 s',
      (tester) async {
        var undone = 0;
        await pumpHost(
          tester,
          theme: AppTheme.lightTheme,
          message: 'Saved',
          onUndo: () => undone++,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(card()).bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byKey(const ValueKey('tab_bar'))).top,
          ),
        );
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(undone, 1);
        expect(card(), findsNothing);

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        expect(card(), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(card(), findsNothing);
      },
    );

    testWidgets('Reduce Motion: shown fully on the first frame', (
      tester,
    ) async {
      double opacityAfterOneFrame() => tester
          .widgetList<FadeTransition>(
            find.ancestor(of: card(), matching: find.byType(FadeTransition)),
          )
          .map((fade) => fade.opacity.value)
          .reduce((a, b) => a * b);

      await pumpHost(tester, theme: AppTheme.lightTheme, message: 'Saved');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(opacityAfterOneFrame(), lessThan(1));
      await tester.pumpAndSettle();

      await pumpHost(
        tester,
        theme: AppTheme.lightTheme,
        message: 'Saved',
        reduceMotion: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(opacityAfterOneFrame(), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('1.35× text wraps to more lines instead of truncating', (
      tester,
    ) async {
      const message =
          'Added 1 katori (150 g) Toor Dal / Yellow Dal Tadka · 186 kcal '
          'to Breakfast';
      await pumpHost(
        tester,
        theme: AppTheme.lightTheme,
        message: message,
        textScale: 1.35,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(message));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      final lineHeight = 14 * 1.35 * 1.2;
      expect(
        tester.getSize(find.text(message)).height,
        greaterThan(lineHeight * 2),
      );
      expect(find.text('1,846 kcal left · +8 g protein'), findsOneWidget);
    });
  });

  group('food log paths', () {
    late RealCatalogue catalogue;
    late List<IndiFitHapticType> haptics;

    setUp(() {
      haptics = [];
      IndiFitHaptics.debugHandler = haptics.add;
    });
    tearDown(() => IndiFitHaptics.debugHandler = null);

    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      bool realRecents = false,
      bool logFirst = false,
    }) async {
      tester.view.physicalSize = const Size(402, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogue = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
      if (logFirst) await tester.runAsync(() => LoggedRecords.log(catalogue));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...loggedRecordsOverrides(catalogue, realRecents: realRecents),
            foodRepositoryProvider.overrideWithValue(
              FoodRepository(catalogue.db),
            ),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await settleLoggedRecords(tester);
    }

    void expectFoodCard(RegExp message) {
      expect(card(), findsOneWidget);
      expect(
        find.descendant(of: card(), matching: find.byType(MealIconChip)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card(), matching: find.textContaining(message)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card(),
          matching: find.textContaining(RegExp(r'^\+[\d.]+ g protein$')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card(), matching: find.text('Undo')),
        findsOneWidget,
      );
    }

    testWidgets('search "+": art, message, day line; above the meal bar', (
      tester,
    ) async {
      await pump(
        tester,
        FoodSearchScreen(
          mealType: 'lunch',
          selectedDate: DateTime(2026, 10, 8),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'poha');
      await tester.pump(const Duration(milliseconds: 800));
      await settleLoggedRecords(tester, rounds: 20);
      await tester.tap(
        find.bySemanticsLabel(RegExp(r'^Add 1 katori Poha')).first,
      );
      await settleLoggedRecords(tester, rounds: 12);

      expectFoodCard(RegExp(r'^Added 1 \w+ Poha.* · 230 kcal to Lunch$'));
      // The fast add's tick is this save's one haptic.
      expect(haptics, [IndiFitHapticType.confirmation]);
      final done = find.descendant(
        of: find.byKey(const ValueKey('food_search_meal_bar')),
        matching: find.text('Done'),
      );
      expect(done, findsOneWidget);
      expect(
        tester.getRect(card()).bottom,
        lessThanOrEqualTo(tester.getRect(done).top),
      );
      // Done stays tappable: nothing of the card sits over it.
      final doneBox = tester.renderObject(done);
      expect(
        tester
            .hitTestOnBinding(tester.getCenter(done))
            .path
            .any((entry) => entry.target == doneBox),
        isTrue,
      );
    });

    testWidgets('portion sheet: art, message, day line, light haptic', (
      tester,
    ) async {
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final option = (await catalogue.catalog.getOption(
                    await catalogue.foodId(loggedRecordsDal),
                  ))!;
                  if (!context.mounted) return;
                  await FoodPortionBottomSheet.show(
                    context,
                    ref: ref,
                    option: option,
                    mealType: 'breakfast',
                    targetDate: DateTime(2026, 10, 8),
                    ensureMealContext: () async => 'breakfast',
                  );
                },
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await settleLoggedRecords(tester, rounds: 10);
      await tester.tap(find.text('Add to Breakfast'));
      await settleLoggedRecords(tester, rounds: 10);

      expectFoodCard(
        RegExp(r'^Added 1 katori \(150 g\) Toor Dal .* kcal to Breakfast$'),
      );
      expect(haptics, contains(IndiFitHapticType.light));
    });

    testWidgets('diary repeat chip: "Added again", day line, Undo', (
      tester,
    ) async {
      await pump(
        tester,
        FoodDiaryScreen(
          selectedDate: DateTime(2026, 10, 8),
          today: DateTime(2026, 10, 8),
        ),
        realRecents: true,
        logFirst: true,
      );
      final chip = find.byType(ActionChip).first;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await settleLoggedRecords(tester, rounds: 10);
      expectFoodCard(RegExp(r'^Added again: '));
      expect(haptics, contains(IndiFitHapticType.light));
    });
  });
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
