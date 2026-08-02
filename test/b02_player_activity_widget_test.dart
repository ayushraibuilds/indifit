import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_activity_session_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/features/activity/b02_activity_creation_screen.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'typed activity form switches to mobility fields without distance',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: B02ActivityCreationScreen()),
        ),
      );
      expect(find.text('Distance (metres, optional)'), findsOneWidget);
      await tester.tap(find.text('Mobility'));
      await tester.pumpAndSettle();
      expect(find.text('Style (optional)'), findsOneWidget);
      expect(find.text('Distance (metres, optional)'), findsNothing);
      expect(find.text('Intensity (optional)'), findsOneWidget);
    },
  );

  testWidgets(
    'strength summary renders actual versus target and explicit partial action',
    (tester) async {
      final state = B02ExecutionDraftState(
        snapshotId: 'snapshot-1',
        snapshotVersion: 1,
        activityType: B02ActivityType.strength,
        routineName: 'Summary press',
        elapsedSeconds: 60,
        currentExerciseOrdinal: 0,
        currentSetOrdinal: 0,
        performedExercises: [
          B02PerformedExerciseDraft(
            id: 'performed-1',
            ordinal: 0,
            expectedExerciseId: 'exercise-1',
            expectedExerciseNameSnapshot: 'Bench press',
            actualExerciseId: 'exercise-1',
            actualExerciseNameSnapshot: 'Bench press',
            status: 'partial',
            sets: [
              B02PerformedSet(
                id: 'set-1',
                performedExerciseId: 'performed-1',
                ordinal: 0,
                role: B02SetRole.working,
                targetRepsMin: 8,
                targetRepsMax: 10,
                actualReps: 8,
              ),
            ],
          ),
        ],
      );
      final launch = B02StrengthExecutionLaunch(
        draftId: 1,
        occurrenceId: null,
        executionSnapshotJson: '{"version":1}',
        state: state,
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: B02StrengthSummaryScreen(launch: launch)),
        ),
      );
      expect(find.textContaining('Target vs actual'), findsNothing);
      expect(find.textContaining('target reps'), findsOneWidget);
      expect(find.text('Finish partially…'), findsOneWidget);
      expect(find.text('Complete workout'), findsOneWidget);
    },
  );

  testWidgets('history card preserves modality and source labels', (
    tester,
  ) async {
    final record = B02TypedActivityHistoryRecord(
      sessionId: 1,
      name: 'Morning yoga',
      activityType: B02ActivityType.yoga,
      source: B02ActivitySource.manual,
      completedAtUtc: DateTime.utc(2026, 1, 1),
      durationSeconds: 900,
      estimatedCalories: 0,
      cardioDetail: null,
      cardioIntervals: const [],
      mobilityDetail: B02MobilitySessionDetail(
        practiceType: B02ActivityType.yoga,
        durationSeconds: 900,
        style: 'Flow',
      ),
      provenance: null,
    );
    await tester.pumpWidget(
      MaterialApp(home: B02ActivityHistoryCard(record: record)),
    );
    expect(find.textContaining('yoga'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Flow'), findsOneWidget);
    expect(find.textContaining('manual'), findsOneWidget);
  });
}
