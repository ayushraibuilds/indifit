import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/features/workout_player/models/workout_completion_recap.dart';
import 'package:indifit/features/workout_player/widgets/workout_share_card.dart';

B02PerformedExerciseHistory _createExercise({
  required String id,
  required int ordinal,
  required String actualExerciseId,
  required String actualExerciseNameSnapshot,
  required List<B02PerformedSet> sets,
  String status = 'completed',
}) {
  return B02PerformedExerciseHistory(
    id: id,
    performedExerciseGroupId: null,
    sourceExercisePrescriptionId: null,
    groupMemberOrdinal: null,
    groupRoundOrdinal: null,
    ordinal: ordinal,
    expectedExerciseId: null,
    expectedExerciseNameSnapshot: null,
    actualExerciseId: actualExerciseId,
    actualExerciseNameSnapshot: actualExerciseNameSnapshot,
    status: status,
    substitutionReason: null,
    sets: sets,
  );
}

void main() {
  group('PV1-PROD-01: WorkoutCompletionRecap model', () {
    test('fromHistory computes exact factual metrics and exercise summaries', () {
      final history = B02StrengthHistoryDetail(
        sessionId: 101,
        name: 'Full Body Push',
        completedAt: DateTime.utc(2026, 9, 5, 10, 30),
        durationSeconds: 3665, // 1h 1m 5s
        completionKind: 'full',
        totalVolumeKg: 2500.0,
        scheduledOccurrenceId: null,
        groups: const [],
        exercises: [
          _createExercise(
            id: 'ex-1',
            ordinal: 0,
            actualExerciseId: 'bench-press',
            actualExerciseNameSnapshot: 'Barbell Bench Press',
            sets: [
              B02PerformedSet(
                id: 's-1',
                performedExerciseId: 'ex-1',
                ordinal: 0,
                role: B02SetRole.warmup,
                actualLoadKg: 40.0,
                actualReps: 10,
              ),
              B02PerformedSet(
                id: 's-2',
                performedExerciseId: 'ex-1',
                ordinal: 1,
                role: B02SetRole.working,
                actualLoadKg: 80.0,
                actualReps: 8,
              ),
              B02PerformedSet(
                id: 's-3',
                performedExerciseId: 'ex-1',
                ordinal: 2,
                role: B02SetRole.working,
                actualLoadKg: 85.0,
                actualReps: 6,
              ),
            ],
          ),
          _createExercise(
            id: 'ex-2',
            ordinal: 1,
            actualExerciseId: 'overhead-press',
            actualExerciseNameSnapshot: 'Overhead Press',
            sets: [
              B02PerformedSet(
                id: 's-4',
                performedExerciseId: 'ex-2',
                ordinal: 0,
                role: B02SetRole.working,
                actualLoadKg: 50.0,
                actualReps: 10,
              ),
            ],
          ),
        ],
      );

      final recap = WorkoutCompletionRecap.fromHistory(history);

      expect(recap.sessionId, 101);
      expect(recap.workoutTitle, 'Full Body Push');
      expect(recap.durationSeconds, 3665);
      expect(recap.formattedDuration, '1h 1m');
      expect(recap.isPartial, false);
      expect(recap.totalVolumeKg, 2500.0);
      expect(recap.completedSetsCount, 4); // 3 + 1
      expect(recap.completedExercisesCount, 2);
      expect(recap.totalRepsCount, 34); // 10 + 8 + 6 + 10
      expect(recap.isFirstSession, true);

      expect(recap.exercises.length, 2);
      final bench = recap.exercises[0];
      expect(bench.exerciseName, 'Barbell Bench Press');
      expect(bench.setsCount, 3);
      expect(bench.topWeightKg, 85.0);
      expect(bench.minReps, 6);
      expect(bench.maxReps, 10);

      final ohp = recap.exercises[1];
      expect(ohp.exerciseName, 'Overhead Press');
      expect(ohp.setsCount, 1);
      expect(ohp.topWeightKg, 50.0);
      expect(ohp.minReps, 10);
      expect(ohp.maxReps, 10);
    });

    test('fromHistory computes comparison delta against previous session', () {
      final prevHistory = B02StrengthHistoryDetail(
        sessionId: 99,
        name: 'Full Body Push',
        completedAt: DateTime.utc(2026, 9, 1, 10, 0),
        durationSeconds: 3200,
        completionKind: 'full',
        totalVolumeKg: 2200.0,
        scheduledOccurrenceId: null,
        groups: const [],
        exercises: [
          _createExercise(
            id: 'ex-prev',
            ordinal: 0,
            actualExerciseId: 'bench-press',
            actualExerciseNameSnapshot: 'Barbell Bench Press',
            sets: [
              B02PerformedSet(
                id: 's-p1',
                performedExerciseId: 'ex-prev',
                ordinal: 0,
                role: B02SetRole.working,
                actualLoadKg: 80.0,
                actualReps: 8,
              ),
              B02PerformedSet(
                id: 's-p2',
                performedExerciseId: 'ex-prev',
                ordinal: 1,
                role: B02SetRole.working,
                actualLoadKg: 80.0,
                actualReps: 8,
              ),
            ],
          ),
        ],
      );

      final currentHistory = B02StrengthHistoryDetail(
        sessionId: 101,
        name: 'Full Body Push',
        completedAt: DateTime.utc(2026, 9, 5, 10, 30),
        durationSeconds: 3400,
        completionKind: 'full',
        totalVolumeKg: 2500.0,
        scheduledOccurrenceId: null,
        groups: const [],
        exercises: [
          _createExercise(
            id: 'ex-curr',
            ordinal: 0,
            actualExerciseId: 'bench-press',
            actualExerciseNameSnapshot: 'Barbell Bench Press',
            sets: [
              B02PerformedSet(
                id: 's-c1',
                performedExerciseId: 'ex-curr',
                ordinal: 0,
                role: B02SetRole.working,
                actualLoadKg: 85.0,
                actualReps: 8,
              ),
              B02PerformedSet(
                id: 's-c2',
                performedExerciseId: 'ex-curr',
                ordinal: 1,
                role: B02SetRole.working,
                actualLoadKg: 85.0,
                actualReps: 8,
              ),
              B02PerformedSet(
                id: 's-c3',
                performedExerciseId: 'ex-curr',
                ordinal: 2,
                role: B02SetRole.working,
                actualLoadKg: 85.0,
                actualReps: 6,
              ),
            ],
          ),
        ],
      );

      final recap = WorkoutCompletionRecap.fromHistory(
        currentHistory,
        previousHistory: prevHistory,
      );

      expect(recap.isFirstSession, false);
      expect(recap.previousComparison, isNotNull);
      expect(recap.previousComparison!.volumeDeltaKg, 300.0);
      expect(recap.previousComparison!.setsDelta, 1);
    });

    test('fromLaunch calculates metrics correctly from in-memory launch draft', () {
      final launch = B02StrengthExecutionLaunch(
        draftId: 1,
        occurrenceId: null,
        executionSnapshotJson: '{}',
        state: B02ExecutionDraftState(
          snapshotId: 'snap-1',
          snapshotVersion: 1,
          activityType: B02ActivityType.strength,
          routineName: 'Morning Upper',
          elapsedSeconds: 150,
          currentExerciseOrdinal: 0,
          currentSetOrdinal: 0,
          performedExercises: [
            B02PerformedExerciseDraft(
              id: 'd-ex-1',
              ordinal: 0,
              actualExerciseId: 'pull-ups',
              actualExerciseNameSnapshot: 'Pull-ups',
              status: 'completed',
              sets: [
                B02PerformedSet(
                  id: 'd-s-1',
                  performedExerciseId: 'd-ex-1',
                  ordinal: 0,
                  role: B02SetRole.working,
                  actualLoadKg: 0.0,
                  actualReps: 12,
                ),
                B02PerformedSet(
                  id: 'd-s-2',
                  performedExerciseId: 'd-ex-1',
                  ordinal: 1,
                  role: B02SetRole.working,
                  actualLoadKg: 10.0,
                  actualReps: 8,
                ),
              ],
            ),
          ],
        ),
      );

      final recap = WorkoutCompletionRecap.fromLaunch(launch);

      expect(recap.workoutTitle, 'Morning Upper');
      expect(recap.durationSeconds, 150);
      expect(recap.formattedDuration, '2m 30s');
      expect(recap.completedSetsCount, 2);
      expect(recap.totalRepsCount, 20);
      expect(recap.totalVolumeKg, 80.0); // 10.0 * 8
      expect(recap.isFirstSession, true);
    });

    test('generateShareText produces factual output with privacy redactions', () {
      final history = B02StrengthHistoryDetail(
        sessionId: 101,
        name: 'Leg Day',
        completedAt: DateTime.utc(2026, 9, 5, 10, 30),
        durationSeconds: 1800,
        completionKind: 'full',
        totalVolumeKg: 3200.0,
        scheduledOccurrenceId: null,
        groups: const [],
        exercises: [
          _createExercise(
            id: 'ex-1',
            ordinal: 0,
            actualExerciseId: 'squat',
            actualExerciseNameSnapshot: 'Back Squat',
            sets: [
              B02PerformedSet(
                id: 's-1',
                performedExerciseId: 'ex-1',
                ordinal: 0,
                role: B02SetRole.working,
                actualLoadKg: 100.0,
                actualReps: 5,
              ),
            ],
          ),
        ],
      );

      final recap = WorkoutCompletionRecap.fromHistory(history);

      // 1. With weights
      final textWithWeights = recap.generateShareText(includeWeights: true);
      expect(textWithWeights, contains('IndiFit Workout: Leg Day'));
      expect(textWithWeights, contains('Duration: 30m 0s'));
      expect(textWithWeights, contains('Total Volume: 3200.0 kg'));
      expect(textWithWeights, contains('Back Squat: 1 sets × 5 reps (top: 100.0 kg)'));
      expect(textWithWeights, contains('Milestone: First time logging this routine!'));

      // Invariants check: NEVER contains speculative metrics
      expect(textWithWeights, isNot(contains('e1RM')));
      expect(textWithWeights, isNot(contains('calories')));
      expect(textWithWeights, isNot(contains('readiness')));

      // 2. Privacy redacted (without weights)
      final textWithoutWeights = recap.generateShareText(includeWeights: false);
      expect(textWithoutWeights, contains('IndiFit Workout: Leg Day'));
      expect(textWithoutWeights, contains('Duration: 30m 0s'));
      expect(textWithoutWeights, isNot(contains('Total Volume:')));
      expect(textWithoutWeights, isNot(contains('100.0 kg')));
      expect(textWithoutWeights, contains('Back Squat: 1 sets × 5 reps'));
    });
  });

  group('PV1-PROD-01: WorkoutShareCard Widget', () {
    testWidgets('renders all factual metrics and share button correctly', (tester) async {
      final history = B02StrengthHistoryDetail(
        sessionId: 101,
        name: 'Push Routine',
        completedAt: DateTime.utc(2026, 9, 5, 10, 30),
        durationSeconds: 2400,
        completionKind: 'full',
        totalVolumeKg: 1850.5,
        scheduledOccurrenceId: null,
        groups: const [],
        exercises: [
          _createExercise(
            id: 'ex-1',
            ordinal: 0,
            actualExerciseId: 'dips',
            actualExerciseNameSnapshot: 'Chest Dips',
            sets: [
              B02PerformedSet(
                id: 's-1',
                performedExerciseId: 'ex-1',
                ordinal: 0,
                role: B02SetRole.working,
                actualLoadKg: 20.0,
                actualReps: 10,
              ),
            ],
          ),
        ],
      );

      final recap = WorkoutCompletionRecap.fromHistory(history);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkoutShareCard(recap: recap),
            ),
          ),
        ),
      );

      // Verify header
      expect(find.text('Push Routine'), findsOneWidget);
      expect(find.text('40m 0s'), findsOneWidget);

      // Verify metric chips
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // Exercises: 1, Sets: 1
      expect(find.text('Sets'), findsOneWidget);
      expect(find.text('Reps'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('1850.5 kg'), findsOneWidget);

      // Verify milestone first session notice
      expect(find.text('First time logging this routine'), findsOneWidget);

      // Verify privacy switch toggle
      expect(find.text('Include weights in share'), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Toggle switch to off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify volume chip hidden when privacy mode is active
      expect(find.text('Volume'), findsNothing);

      // Verify share button presence
      final shareButton = find.byKey(const Key('workout_share_button'));
      expect(shareButton, findsOneWidget);
      expect(find.text('Share workout recap'), findsOneWidget);
    });
  });
}
