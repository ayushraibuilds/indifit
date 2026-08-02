import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_muscle_volume_models.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/features/progress/b02_progress_widgets.dart';

void main() {
  testWidgets('history card labels legacy provenance and typed modality', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: B02ProgressActivityHistoryCard(
            records: [
              B02ProgressActivityRecord(
                sessionId: 1,
                name: 'Old workout',
                activityType: B02ActivityType.legacy,
                recordKind: B02HistoryRecordKind.legacyProjection,
                completedAtUtc: DateTime.utc(2026, 8, 1),
                durationSeconds: 300,
                source: null,
                legacySetCount: 4,
                performedExerciseCount: 0,
                performedGroupCount: 0,
                cardioIntervalCount: 0,
                hasCardioDetail: false,
                hasMobilityDetail: false,
                cardioDetail: null,
                mobilityDetail: null,
              ),
              B02ProgressActivityRecord(
                sessionId: 2,
                name: 'Run',
                activityType: B02ActivityType.running,
                recordKind: B02HistoryRecordKind.canonical,
                completedAtUtc: DateTime.utc(2026, 8, 2),
                durationSeconds: 600,
                source: B02ActivitySource.manual,
                legacySetCount: 0,
                performedExerciseCount: 0,
                performedGroupCount: 0,
                cardioIntervalCount: 3,
                hasCardioDetail: true,
                hasMobilityDetail: false,
                cardioDetail: null,
                mobilityDetail: null,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Legacy B01 projection · 4 sets'),
      findsOneWidget,
    );
    expect(find.textContaining('Running'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
  });

  testWidgets(
    'muscle card renders textual unknown coverage, not a zero value',
    (tester) async {
      final model = B02MuscleVolumeReadModel(
        startLocalDate: '2026-08-01',
        endLocalDate: '2026-08-07',
        timezoneId: 'UTC',
        startUtc: DateTime.utc(2026, 8, 1),
        endExclusiveUtc: DateTime.utc(2026, 8, 8),
        muscles: const [
          B02MuscleVolumeCell(
            muscleId: 'chest',
            displayName: 'Chest',
            region: 'torso',
            catalogVersion: 1,
            workingSetUnits: 2,
            effectiveSetUnits: null,
            effectiveEvidenceUnits: 0,
          ),
        ],
        unknown: const B02MuscleVolumeUnknown(
          workingSetUnits: 1,
          effectiveSetUnits: null,
          effectiveEvidenceUnits: 0,
          workingSetCount: 1,
        ),
        totalWorkingSetCount: 3,
        mappedWorkingSetCount: 2,
        mappedWorkingSetUnits: 2,
        mappedEffectiveSetUnits: null,
        totalEffectiveEvidenceUnits: 0,
        legacySetCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: B02ProgressMuscleHeatMapCard(readModel: model)),
        ),
      );

      expect(find.textContaining('Unknown'), findsWidgets);
      expect(
        find.textContaining('Unknown mapping: 1 working sets'),
        findsOneWidget,
      );
      expect(find.textContaining('Legacy history: 1 sets'), findsOneWidget);
      expect(find.textContaining('mapped: 2 (67%)'), findsOneWidget);
    },
  );

  testWidgets('target card explains missing evidence and override', (
    tester,
  ) async {
    final recommendation = B02TargetRecommendation(
      id: 'recommendation',
      performedExerciseId: 'performed',
      ruleVersion: 'b02-target-v1',
      confidence: B02Confidence.medium,
      completeness: const {'recovery': 'unknown'},
      recommendedLoadKg: 50,
      targetRepsMin: 6,
      targetRepsMax: 8,
      comparatorCount: 2,
      rationaleCodes: const ['recovery-unknown'],
      wasOverridden: true,
    );
    final rows = [
      B02ProgressTargetEvidence(
        sessionId: 1,
        completedAtUtc: DateTime.utc(2026, 8, 1),
        performedExerciseId: 'performed',
        actualExerciseId: 'bench',
        actualExerciseName: 'Bench',
        status: 'completed',
        expectedExerciseName: 'Bench',
        substitutionReason: null,
        workingSetCount: 2,
        totalSetCount: 2,
        recommendation: recommendation,
      ),
      B02ProgressTargetEvidence(
        sessionId: 1,
        completedAtUtc: DateTime.utc(2026, 8, 1),
        performedExerciseId: 'missing',
        actualExerciseId: 'row',
        actualExerciseName: 'Row',
        status: 'completed',
        expectedExerciseName: 'Row',
        substitutionReason: null,
        workingSetCount: 1,
        totalSetCount: 1,
        recommendation: null,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: B02ProgressTargetEvidenceCard(records: rows)),
      ),
    );

    expect(find.textContaining('medium confidence'), findsOneWidget);
    expect(find.text('User override'), findsOneWidget);
    expect(find.textContaining('No target evidence recorded'), findsOneWidget);
    expect(find.textContaining('Why: recovery-unknown'), findsOneWidget);
  });

  testWidgets('heat-map card remains usable at compact screen size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final model = B02MuscleVolumeReadModel(
      startLocalDate: '2026-08-01',
      endLocalDate: '2026-08-07',
      timezoneId: 'UTC',
      startUtc: DateTime.utc(2026, 8, 1),
      endExclusiveUtc: DateTime.utc(2026, 8, 8),
      muscles: const [
        B02MuscleVolumeCell(
          muscleId: 'chest',
          displayName: 'Chest',
          region: 'torso',
          catalogVersion: 1,
          workingSetUnits: 2,
          effectiveSetUnits: 2,
          effectiveEvidenceUnits: 2,
        ),
      ],
      unknown: const B02MuscleVolumeUnknown(
        workingSetUnits: 0,
        effectiveSetUnits: 0,
        effectiveEvidenceUnits: 0,
        workingSetCount: 0,
      ),
      totalWorkingSetCount: 2,
      mappedWorkingSetCount: 2,
      mappedWorkingSetUnits: 2,
      mappedEffectiveSetUnits: 2,
      totalEffectiveEvidenceUnits: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: B02ProgressMuscleHeatMapCard(readModel: model)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Chest'), findsOneWidget);
  });
}
