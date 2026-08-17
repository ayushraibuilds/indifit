import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/features/dashboard/widgets/calorie_ring_card.dart';
import 'package:indifit/features/food_log/saved_meals_controller.dart';
import 'package:indifit/features/food_log/saved_meals_screen.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

void main() {
  group('R07F-2 — IndiFitHaptics & Motion Policy', () {
    final emittedEvents = <IndiFitHapticType>[];

    setUp(() {
      emittedEvents.clear();
      IndiFitHaptics.debugHandler = (type) => emittedEvents.add(type);
    });

    tearDown(() {
      IndiFitHaptics.debugHandler = null;
      emittedEvents.clear();
    });

    test(
      'IndiFitHaptics triggers selection, confirmation, and warning correctly',
      () async {
        await IndiFitHaptics.selection();
        expect(emittedEvents, [IndiFitHapticType.selection]);

        await IndiFitHaptics.confirmation();
        expect(emittedEvents, [
          IndiFitHapticType.selection,
          IndiFitHapticType.confirmation,
        ]);

        await IndiFitHaptics.warning();
        expect(emittedEvents, [
          IndiFitHapticType.selection,
          IndiFitHapticType.confirmation,
          IndiFitHapticType.warning,
        ]);
      },
    );

    test('IndiFitHaptics absorbs optional hook failures', () async {
      IndiFitHaptics.debugHandler = (_) => throw StateError('test hook');

      await expectLater(IndiFitHaptics.confirmation(), completes);
    });

    testWidgets('B05MotionPolicy respects standard vs reduced motion', (
      tester,
    ) async {
      late BuildContext capturedContext;

      // 1. Normal motion
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(B05MotionPolicy.reduceMotion(capturedContext), isFalse);
      expect(
        B05MotionPolicy.transitionDuration(capturedContext),
        B05MotionPolicy.standardDuration,
      );
      expect(
        B05MotionPolicy.transitionDuration(
          capturedContext,
          standard: B05MotionPolicy.fastDuration,
        ),
        B05MotionPolicy.fastDuration,
      );

      // 2. Reduced motion
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(B05MotionPolicy.reduceMotion(capturedContext), isTrue);
      expect(
        B05MotionPolicy.transitionDuration(capturedContext),
        Duration.zero,
      );
      expect(
        B05MotionPolicy.transitionDuration(
          capturedContext,
          standard: B05MotionPolicy.completionDuration,
        ),
        Duration.zero,
      );
    });
  });

  group('R07F-2 — Today Calorie Ring & Macro Bars State Continuity', () {
    testWidgets(
      'CalorieRingCard renders and settles smoothly under standard motion',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: CalorieRingCard(
                  eatenCalories: 1450,
                  eatenProtein: 120.0,
                  eatenCarbs: 160.0,
                  eatenFat: 45.0,
                  eatenFiber: 25.0,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('1450'), findsOneWidget);
        expect(find.text('Protein'), findsOneWidget);
        expect(find.text('Carbs'), findsOneWidget);
        expect(find.text('Fat'), findsOneWidget);
        expect(find.text('Fiber'), findsOneWidget);
      },
    );

    testWidgets(
      'CalorieRingCard renders instantly without animation under reduced motion',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: Scaffold(
                  body: CalorieRingCard(
                    eatenCalories: 2000,
                    eatenProtein: 150.0,
                    eatenCarbs: 220.0,
                    eatenFat: 60.0,
                    eatenFiber: 30.0,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('2000'), findsOneWidget);
        expect(find.text('Protein'), findsOneWidget);
      },
    );

    testWidgets(
      'CalorieRingCard starts settled, then interpolates only semantic changes',
      (tester) async {
        final semantics = tester.ensureSemantics();

        Widget buildCard(int calories) => ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CalorieRingCard(
                key: const ValueKey('review-calorie-ring'),
                eatenCalories: calories,
                eatenProtein: 120,
                eatenCarbs: 160,
                eatenFat: 45,
                eatenFiber: 25,
              ),
            ),
          ),
        );

        double ringValue() => tester
            .widget<CircularPercentIndicator>(
              find.byType(CircularPercentIndicator),
            )
            .percent;

        await tester.pumpWidget(buildCard(1200));
        await tester.pump();
        expect(ringValue(), closeTo(0.6, 0.001));
        expect(
          find.bySemanticsLabel('1200 of 2000 calories logged'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Protein: 120 of 120 grams'),
          findsOneWidget,
        );

        await tester.pumpWidget(buildCard(1600));
        await tester.pump();
        expect(ringValue(), closeTo(0.6, 0.001));

        await tester.pump(const Duration(milliseconds: 120));
        expect(ringValue(), greaterThan(0.6));
        expect(ringValue(), lessThan(0.8));

        await tester.pumpAndSettle();
        expect(ringValue(), closeTo(0.8, 0.001));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(buildCard(1600));
        await tester.pump();
        expect(ringValue(), closeTo(0.8, 0.001));
        semantics.dispose();
      },
    );
  });

  group('R07F-2 — Feedback timing and duplicate protection', () {
    final emittedEvents = <IndiFitHapticType>[];

    setUp(() {
      emittedEvents.clear();
      IndiFitHaptics.debugHandler = emittedEvents.add;
    });

    tearDown(() {
      IndiFitHaptics.debugHandler = null;
      emittedEvents.clear();
    });

    testWidgets(
      'Saved Meal fast re-log is guarded before its async context resolves',
      (tester) async {
        final controller = _ReviewSavedMealsController()
          ..logGate = Completer<NutritionConsumptionSnapshot?>();
        controller.state = SavedMealsState(
          status: SavedMealsStatus.ready,
          meals: [_reviewSavedMeal()],
        );
        final container = ProviderContainer(
          overrides: [
            savedMealsControllerProvider.overrideWith((ref) => controller),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'UTC'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SavedMealsScreen(mealType: 'lunch')),
          ),
        );
        await tester.pump();

        final logButton = find.text('LOG TO LUNCH');
        await tester.tap(logButton);
        await tester.tap(logButton);
        await tester.pumpAndSettle();

        expect(controller.logCalls, 1);
        expect(emittedEvents, isEmpty);
      },
    );

    testWidgets(
      'Saved Meal delete warns only after the canonical deletion succeeds',
      (tester) async {
        final controller = _ReviewSavedMealsController()
          ..deleteGate = Completer<bool>();
        controller.state = SavedMealsState(
          status: SavedMealsStatus.ready,
          meals: [_reviewSavedMeal()],
        );
        final container = ProviderContainer(
          overrides: [
            savedMealsControllerProvider.overrideWith((ref) => controller),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SavedMealsScreen(mealType: 'lunch')),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(emittedEvents, isEmpty);

        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pump();

        expect(controller.deleteCalls, 1);
        expect(emittedEvents, isEmpty);

        controller.deleteGate!.complete(true);
        await tester.pump();
        await tester.pump();
        expect(emittedEvents, [IndiFitHapticType.warning]);
      },
    );

    testWidgets('weight range feedback fires only when the range changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ProgressScreen(preview: _rangeFeedbackSnapshot()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final oneMonth = find.widgetWithText(ChoiceChip, '1M');
      await tester.ensureVisible(oneMonth);
      await tester.tap(oneMonth);
      await tester.pump();
      expect(emittedEvents, isEmpty);

      final threeMonths = find.widgetWithText(ChoiceChip, '3M');
      await tester.ensureVisible(threeMonths);
      await tester.tap(threeMonths);
      await tester.pump();
      expect(emittedEvents, [IndiFitHapticType.selection]);
    });
  });

  group('R07F-2 — Workout Completion Polish', () {
    final mockLaunch = B02StrengthExecutionLaunch(
      draftId: 101,
      occurrenceId: 'occ-101',
      executionSnapshotJson: '{}',
      state: B02ExecutionDraftState(
        snapshotId: 'snap-101',
        snapshotVersion: 1,
        activityType: B02ActivityType.strength,
        currentExerciseOrdinal: 0,
        currentSetOrdinal: 0,
        routineName: 'Upper Body Power',
        elapsedSeconds: 2700,
        performedExercises: [
          B02PerformedExerciseDraft(
            id: 'pe-1',
            ordinal: 0,
            actualExerciseId: 'bench-press',
            actualExerciseNameSnapshot: 'Barbell Bench Press',
            status: 'completed',
            sets: [
              B02PerformedSet(
                id: 'ps-1',
                performedExerciseId: 'pe-1',
                ordinal: 0,
                role: B02SetRole.working,
                actualReps: 8,
                actualLoadKg: 80.0,
                actualLoadBasis: B02LoadBasis.totalExternal,
              ),
              B02PerformedSet(
                id: 'ps-2',
                performedExerciseId: 'pe-1',
                ordinal: 1,
                role: B02SetRole.working,
                actualReps: 8,
                actualLoadKg: 80.0,
                actualLoadBasis: B02LoadBasis.totalExternal,
              ),
            ],
          ),
        ],
      ),
    );

    testWidgets(
      'B02WorkoutCompletionSuccess displays truthful summary without PR claims',
      (tester) async {
        var doneCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: B02WorkoutCompletionSuccess(
                launch: mockLaunch,
                onDone: () => doneCalled = true,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Workout complete'), findsOneWidget);
        expect(find.text('Upper Body Power'), findsOneWidget);
        expect(find.text('45 min'), findsOneWidget); // 2700s = 45 min
        expect(find.text('Duration'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // 1 exercise
        expect(find.text('Exercises'), findsOneWidget);
        expect(find.text('2'), findsOneWidget); // 2 sets
        expect(find.text('Sets'), findsOneWidget);
        expect(find.text('16'), findsOneWidget); // 8 + 8 reps
        expect(find.text('Reps'), findsOneWidget);
        expect(find.text('1280 kg'), findsOneWidget); // 80*8 + 80*8 = 1280
        expect(find.text('External volume'), findsOneWidget);

        // Verify strict absence of unearned PR / gamification copy
        expect(find.textContaining('PERSONAL RECORD'), findsNothing);
        expect(find.textContaining('NEW PR'), findsNothing);
        expect(find.textContaining('STRONGEST'), findsNothing);

        // Tap Done
        final doneBtn = find.text('Done');
        expect(doneBtn, findsOneWidget);
        await tester.tap(doneBtn);
        expect(doneCalled, isTrue);
      },
    );

    testWidgets('B02WorkoutCompletionSuccess respects reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: B02WorkoutCompletionSuccess(
                launch: mockLaunch,
                onDone: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Workout complete'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}

SavedMealDisplayItem _reviewSavedMeal() => SavedMealDisplayItem(
  draft: NutritionThaliDraft(
    id: 'thali::r07f2-review',
    userId: kLocalNutritionUserScopeId,
    name: 'Review meal',
    description: null,
    lifecycle: 'active',
    currentVersion: 1,
    createdAtUtc: DateTime.utc(2026, 8, 17),
    updatedAtUtc: DateTime.utc(2026, 8, 17),
    items: const [],
  ),
  itemCount: 1,
  estimatedCalories: 500,
  estimatedProteinG: 25,
  summary: 'Review item',
);

class _ReviewSavedMealsController extends SavedMealsController {
  _ReviewSavedMealsController()
    : super(
        thaliRepoFuture: Completer<NutritionThaliRepository>().future,
        userId: kLocalNutritionUserScopeId,
      );

  int logCalls = 0;
  int deleteCalls = 0;
  Completer<NutritionConsumptionSnapshot?>? logGate;
  Completer<bool>? deleteGate;

  @override
  Future<NutritionConsumptionSnapshot?> logSavedMeal({
    required NutritionThaliDraft draft,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    bool allowPartial = true,
  }) async {
    logCalls++;
    final gate = logGate;
    return gate == null ? null : await gate.future;
  }

  @override
  Future<bool> deleteSavedMeal(String thaliId, {bool reload = true}) {
    deleteCalls++;
    return deleteGate?.future ?? Future<bool>.value(false);
  }

  @override
  Future<void> loadSavedMeals({String query = ''}) async {}
}

ProgressDashboardSnapshot _rangeFeedbackSnapshot() => ProgressDashboardSnapshot(
  nowUtc: DateTime.utc(2026, 8, 17, 12),
  timezoneId: 'UTC',
  todayLocalDate: '2026-08-17',
  measurements: [
    ProgressMeasurementRecord(
      id: 1,
      recordedAt: DateTime.utc(2026, 4, 10, 8),
      localDate: '2026-04-10',
      weightKg: 81,
    ),
    ProgressMeasurementRecord(
      id: 2,
      recordedAt: DateTime.utc(2026, 6, 12, 8),
      localDate: '2026-06-12',
      weightKg: 80,
    ),
    ProgressMeasurementRecord(
      id: 3,
      recordedAt: DateTime.utc(2026, 8, 17, 8),
      localDate: '2026-08-17',
      weightKg: 79,
    ),
  ],
  workouts: const [],
  strengthSets: const [],
  muscleBalance: null,
  unavailableSections: const {},
);
