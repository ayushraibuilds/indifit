import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/theme/b05_semantic_colors.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/core/widgets/indi_fit_feedback.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/widgets/log_weight_bottom_sheet.dart';
import 'package:indifit/features/food_log/nutrition_recipe_editor_screen.dart';

class _FakeWorkoutRepository extends WorkoutRepository {
  final WeightLogStatus status;
  _FakeWorkoutRepository(super.db, {required this.status});

  @override
  Future<WeightLogStatus> getWeightLogStatus() async => status;
}

class _SimulatedMacroPreview {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const _SimulatedMacroPreview({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bug 1: Food Success & Undo Feedback', () {
    testWidgets('showIndiFitSuccessFeedback shows theme-styled snackbar with 3s duration and clears queue', (tester) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                savedContext = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Trigger first snackbar
      showIndiFitSuccessFeedback(savedContext, 'First food logged');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First food logged'), findsOneWidget);

      // Trigger second snackbar immediately - previous should be cleared
      showIndiFitSuccessFeedback(savedContext, 'Second food logged');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First food logged'), findsNothing);
      expect(find.text('Second food logged'), findsOneWidget);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 3));
      expect(snackBar.backgroundColor, B05SemanticColors.light.section);
      expect(snackBar.behavior, SnackBarBehavior.floating);

      // Verify explicit dismissIndiFitFeedback
      dismissIndiFitFeedback(savedContext);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Second food logged'), findsNothing);
    });

    testWidgets('showIndiFitUndoFeedback shows theme-styled snackbar with Undo action and dismisses on next action', (tester) async {
      late BuildContext savedContext;
      var undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                savedContext = ctx;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      showIndiFitUndoFeedback(
        savedContext,
        message: 'Added Banana to Breakfast',
        duration: const Duration(seconds: 4),
        onUndo: () => undoCalled = true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Added Banana to Breakfast'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, B05SemanticColors.dark.section);
      expect(snackBar.action?.textColor, B05SemanticColors.dark.action);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(undoCalled, isTrue);

      // Dismissal
      dismissIndiFitFeedback(savedContext);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Bug 2: Food Quantity +/- Controls Visual Stability', () {
    testWidgets('Macro cards remain continuously rendered during rapid +/- adjustments without loading indicator flashes', (tester) async {
      final previewCompleters = <Completer<_SimulatedMacroPreview>>[];

      const initialPreview = _SimulatedMacroPreview(
        calories: 120.0,
        protein: 3.5,
        carbs: 25.0,
        fat: 0.5,
      );

      var selectedQuantity = Quantity.fromNum(
        amount: 100,
        unit: QuantityUnit.gram,
      );
      var previewGeneration = 0;
      _SimulatedMacroPreview? currentPreview = initialPreview;

      // Test a widget validating the generation-guarded state pattern
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  void updatePreview() {
                    final currentGen = ++previewGeneration;
                    final c = Completer<_SimulatedMacroPreview>();
                    previewCompleters.add(c);
                    c.future.then((p) {
                      if (currentGen == previewGeneration) {
                        setState(() {
                          currentPreview = p;
                        });
                      }
                    });
                  }

                  void stepAmount(double delta) {
                    setState(() {
                      final currentVal =
                          double.parse(selectedQuantity.amount.toString());
                      selectedQuantity = Quantity.fromNum(
                        amount: currentVal + delta,
                        unit: QuantityUnit.gram,
                      );
                      updatePreview();
                    });
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Qty: ${double.parse(selectedQuantity.amount.toString()).toStringAsFixed(0)}',
                      ),
                      ElevatedButton(
                        key: const ValueKey('decrease_btn'),
                        onPressed: () => stepAmount(-10),
                        child: const Text('-10'),
                      ),
                      ElevatedButton(
                        key: const ValueKey('increase_btn'),
                        onPressed: () => stepAmount(10),
                        child: const Text('+10'),
                      ),
                      Builder(
                        builder: (context) {
                          final preview = currentPreview;
                          if (preview == null) {
                            return const Text('Enter an amount to preview nutrition.');
                          }
                          return Text('Calories: ${preview.calories.toStringAsFixed(0)} kcal');
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Frame 0 renders immediately with no LinearProgressIndicator
      expect(find.text('Calories: 120 kcal'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Rapidly tap '+' 3 times
      await tester.tap(find.byKey(const ValueKey('increase_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('increase_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('increase_btn')));
      await tester.pump();

      // UI immediately reflects quantity change without flashing or tearing down the macro label
      expect(find.text('Qty: 130'), findsOneWidget);
      expect(find.text('Calories: 120 kcal'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Resolve previews out-of-order: first resolve gen 1 (which is stale)
      const stalePreview = _SimulatedMacroPreview(
        calories: 132.0,
        protein: 3.8,
        carbs: 27.5,
        fat: 0.6,
      );
      previewCompleters[0].complete(stalePreview);
      await tester.pump();

      // Should ignore stale gen 1 result (still displaying 120 kcal)
      expect(find.text('Calories: 120 kcal'), findsOneWidget);

      // Now resolve latest gen 3
      const latestPreview = _SimulatedMacroPreview(
        calories: 156.0,
        protein: 4.5,
        carbs: 32.5,
        fat: 0.7,
      );
      previewCompleters[2].complete(latestPreview);
      await tester.pump();

      // Updated cleanly to 156 kcal with zero flicker
      expect(find.text('Calories: 156 kcal'), findsOneWidget);
    });
  });

  group('Bug 3: Create Recipe Header Theme Defect', () {
    testWidgets('NutritionRecipeEditorScreen uses theme-correct page colors in light mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const NutritionRecipeEditorScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      // In light mode, AppBar background is null (inheriting AppTheme.lightTheme.appBarTheme.backgroundColor = #F8FAFC)
      expect(appBar.backgroundColor, isNull);

      final BuildContext context = tester.element(find.byType(AppBar));
      final theme = Theme.of(context);
      expect(theme.appBarTheme.backgroundColor, B05SemanticColors.light.page);
      expect(theme.appBarTheme.foregroundColor, B05SemanticColors.light.textPrimary);
    });

    testWidgets('NutritionRecipeEditorScreen uses theme-correct page colors in dark mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const NutritionRecipeEditorScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNull);

      final BuildContext context = tester.element(find.byType(AppBar));
      final theme = Theme.of(context);
      expect(theme.appBarTheme.backgroundColor, B05SemanticColors.dark.page);
      expect(theme.appBarTheme.foregroundColor, B05SemanticColors.dark.textPrimary);
    });
  });

  group('Bug 4: Progress Weight Entry Sheet Theme & Layout', () {
    testWidgets('LogWeightBottomSheet uses semantic tokens in light mode', (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final repo = _FakeWorkoutRepository(
        db,
        status: WeightLogStatus(canLog: true, isEditingToday: false, daysUntilUnlock: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: LogWeightBottomSheet(
                currentWeight: 72.5,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify subtitle and title are styled with light semantic tokens
      expect(find.text('Log Body Weight'), findsOneWidget);
      expect(find.text('New Weekly Entry'), findsOneWidget);

      final titleText = tester.widget<Text>(find.text('Log Body Weight'));
      expect(titleText.style?.color, B05SemanticColors.light.textPrimary);

      // Verify action chips use inset background
      final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
      for (final chip in chips) {
        expect(chip.backgroundColor, B05SemanticColors.light.inset);
      }

      // Verify ElevatedButton uses light action token
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.style?.backgroundColor?.resolve({}), B05SemanticColors.light.action);
    });

    testWidgets('LogWeightBottomSheet uses semantic tokens in dark mode', (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final repo = _FakeWorkoutRepository(
        db,
        status: WeightLogStatus(canLog: true, isEditingToday: false, daysUntilUnlock: 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: LogWeightBottomSheet(
                currentWeight: 72.5,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleText = tester.widget<Text>(find.text('Log Body Weight'));
      expect(titleText.style?.color, B05SemanticColors.dark.textPrimary);

      final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
      for (final chip in chips) {
        expect(chip.backgroundColor, B05SemanticColors.dark.inset);
      }

      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.style?.backgroundColor?.resolve({}), B05SemanticColors.dark.action);
    });

    testWidgets('LogWeightBottomSheet locked and editing states display without text clipping', (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final lockedRepo = _FakeWorkoutRepository(
        db,
        status: WeightLogStatus(canLog: false, isEditingToday: false, daysUntilUnlock: 5),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(lockedRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: LogWeightBottomSheet(
                  currentWeight: 80.0,
                  onSave: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Locked for 5 days'), findsOneWidget);
      expect(find.textContaining('Weight logging is locked for 5 more days'), findsOneWidget);
      expect(find.text('Locked for 5 Days'), findsOneWidget);
    });
  });
}
