import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_progress_read_models.dart';
import 'package:indifit/data/repositories/b02_progress_read_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await _insertExercise(db, 'canonical-bench', 'Canonical Bench');
    await _insertExercise(db, 'canonical-row', 'Canonical Row');
  });

  tearDown(() => db.close());

  test('keeps legacy and canonical activity history distinct', () async {
    final legacySession = await _insertSession(
      db,
      name: 'Old workout',
      activityType: 'legacy',
      completedAt: DateTime.utc(2026, 8, 1, 8),
    );
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            sessionId: legacySession,
            exerciseName: 'Bench by name',
            weight: 20,
            reps: 8,
            setNumber: 1,
          ),
        );
    await _insertSession(
      db,
      name: 'Canonical cardio',
      activityType: 'running',
      completedAt: DateTime.utc(2026, 8, 2, 8),
    );

    final records = await B02ProgressReadRepository(db).readActivityHistory(
      const B02ProgressQuery(
        startLocalDate: '2026-08-01',
        endLocalDate: '2026-08-02',
        timezoneId: 'UTC',
      ),
    );

    expect(records, hasLength(2));
    final legacy = records.firstWhere((record) => record.isLegacy);
    expect(legacy.activityType, B02ActivityType.legacy);
    expect(legacy.legacySetCount, 1);
    expect(legacy.source, isNull);
    expect(legacy.name, 'Old workout');
  });

  test(
    'reads group members and substitutions from canonical snapshots',
    () async {
      final session = await _insertSession(
        db,
        name: 'Strength day',
        activityType: 'strength',
        completedAt: DateTime.utc(2026, 8, 2, 8),
      );
      await db
          .into(db.performedExerciseGroups)
          .insert(
            PerformedExerciseGroupsCompanion.insert(
              id: 'group-1',
              sessionId: session,
              groupTypeSnapshot: 'superset',
              labelSnapshot: const Value('Push pair'),
              ordinal: 0,
              plannedRounds: 3,
              completedRounds: const Value(2),
              status: const Value('partial'),
            ),
          );
      await _insertPerformedExercise(
        db,
        id: 'performed-bench',
        sessionId: session,
        groupId: 'group-1',
        expectedId: 'canonical-bench',
        expectedName: 'Bench press',
        actualId: 'canonical-row',
        actualName: 'Row substitution',
        substitutionReason: 'Shoulder discomfort',
      );
      await _insertPerformedExercise(
        db,
        id: 'performed-row',
        sessionId: session,
        groupId: 'group-1',
        expectedId: 'canonical-row',
        expectedName: 'Row',
        actualId: 'canonical-row',
        actualName: 'Row',
        ordinal: 1,
      );
      await _insertSet(db, 'set-1', 'performed-bench', 'working');
      await _insertSet(db, 'set-2', 'performed-bench', 'warmup', ordinal: 1);

      final groups = await B02ProgressReadRepository(db).readGroupHistory(
        const B02ProgressQuery(
          startLocalDate: '2026-08-02',
          endLocalDate: '2026-08-02',
          timezoneId: 'UTC',
        ),
      );

      expect(groups, hasLength(1));
      expect(groups.single.groupType, B02GroupType.superset);
      expect(groups.single.isPartial, isTrue);
      expect(groups.single.members.first.wasSubstituted, isTrue);
      expect(groups.single.members.first.workingSetCount, 1);
      expect(groups.single.members.first.totalSetCount, 2);
    },
  );

  test(
    'returns target evidence and explicit absence without changing history',
    () async {
      final session = await _insertSession(
        db,
        name: 'Target day',
        activityType: 'strength',
        completedAt: DateTime.utc(2026, 8, 2, 8),
      );
      await _insertPerformedExercise(
        db,
        id: 'targeted',
        sessionId: session,
        actualId: 'canonical-bench',
        actualName: 'Bench snapshot',
      );
      await _insertPerformedExercise(
        db,
        id: 'untargeted',
        sessionId: session,
        actualId: 'canonical-row',
        actualName: 'Row snapshot',
        ordinal: 1,
      );
      await db
          .into(db.exerciseTargetRecommendations)
          .insert(
            ExerciseTargetRecommendationsCompanion.insert(
              id: 'recommendation-1',
              performedExerciseId: 'targeted',
              ruleVersion: 'b02-target-v1',
              confidence: 'medium',
              completenessJson: jsonEncode({'recovery': 'unknown'}),
              recommendedLoadKg: const Value(60),
              targetRepsMin: const Value(6),
              targetRepsMax: const Value(8),
              comparatorCount: const Value(2),
              rationaleCodesJson: jsonEncode(['recovery-unknown']),
              wasOverridden: const Value(true),
            ),
          );

      final targets = await B02ProgressReadRepository(db).readTargetEvidence(
        const B02ProgressQuery(
          startLocalDate: '2026-08-02',
          endLocalDate: '2026-08-02',
          timezoneId: 'UTC',
        ),
      );

      expect(targets, hasLength(2));
      final withEvidence = targets.firstWhere(
        (target) => target.performedExerciseId == 'targeted',
      );
      final withoutEvidence = targets.firstWhere(
        (target) => target.performedExerciseId == 'untargeted',
      );
      expect(withEvidence.recommendation?.ruleVersion, 'b02-target-v1');
      expect(withEvidence.wasOverridden, isTrue);
      expect(withEvidence.recommendation?.rationaleCodes, ['recovery-unknown']);
      expect(withoutEvidence.recommendation, isNull);
    },
  );
}

Future<void> _insertExercise(AppDatabase db, String id, String name) async {
  await db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          stableId: Value(id),
          name: name,
          muscleGroups: 'ignored',
          equipment: 'Barbell',
          difficulty: 'Intermediate',
          formCues: 'cue',
          commonMistakes: 'mistake',
        ),
      );
}

Future<int> _insertSession(
  AppDatabase db, {
  required String name,
  required String activityType,
  required DateTime completedAt,
}) => db
    .into(db.workoutSessions)
    .insert(
      WorkoutSessionsCompanion.insert(
        name: name,
        totalVolume: 0,
        durationSeconds: 600,
        estimatedCalories: 0,
        completedAt: Value(completedAt),
        activityType: Value(activityType),
      ),
    );

Future<void> _insertPerformedExercise(
  AppDatabase db, {
  required String id,
  required int sessionId,
  required String actualId,
  required String actualName,
  String? groupId,
  String? expectedId,
  String? expectedName,
  String? substitutionReason,
  int ordinal = 0,
}) async {
  await db
      .into(db.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: id,
          sessionId: sessionId,
          performedExerciseGroupId: Value(groupId),
          ordinal: ordinal,
          expectedExerciseId: Value(expectedId),
          expectedExerciseNameSnapshot: Value(expectedName),
          actualExerciseId: actualId,
          actualExerciseNameSnapshot: actualName,
          status: const Value('completed'),
          substitutionReason: Value(substitutionReason),
        ),
      );
}

Future<void> _insertSet(
  AppDatabase db,
  String id,
  String performedExerciseId,
  String role, {
  int ordinal = 0,
}) async {
  await db
      .into(db.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: id,
          performedExerciseId: performedExerciseId,
          ordinal: ordinal,
          role: role,
        ),
      );
}
