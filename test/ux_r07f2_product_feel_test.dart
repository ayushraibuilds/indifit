import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/indifit_haptics.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/features/dashboard/widgets/calorie_ring_card.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';

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
