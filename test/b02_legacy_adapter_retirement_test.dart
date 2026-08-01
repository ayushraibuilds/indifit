import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/repositories/legacy_workout_compatibility_adapter.dart';
import 'package:indifit/data/repositories/workout_execution_compatibility_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy name rules remain isolated to the compatibility adapter', () {
    const adapter = LegacyWorkoutCompatibilityAdapter();

    expect(adapter.metadataFor('Treadmill Walk').isCardio, isTrue);
    expect(
      adapter.metadataFor('Flat Barbell Bench Press').formCue,
      startsWith('Form: Scapula retracted'),
    );
    expect(adapter.metadataFor('Barbell Squat').recommendedRestSeconds, 120);
    expect(adapter.metadataFor('Dumbbell Curl').recommendedRestSeconds, 60);
    expect(adapter.metadataFor('Flat Row').recommendedRestSeconds, 90);
    expect(LegacyWorkoutCompatibilityAdapter.ruleVersion, isNotEmpty);
  });

  test('legacy adapter refuses to resume a canonical B02 draft', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final draftId = await db
        .into(db.workoutDrafts)
        .insert(
          WorkoutDraftsCompanion.insert(
            routineName: 'Typed strength',
            currentExerciseIndex: 0,
            currentSetIndex: 0,
            elapsedSeconds: 5,
            loggedSetsJson: '[]',
            draftSchemaVersion: const Value(2),
            activityType: const Value('strength'),
            executionStateJson: const Value('{"version":2}'),
          ),
        );
    final draft = await (db.select(
      db.workoutDrafts,
    )..where((table) => table.id.equals(draftId))).getSingle();
    final adapter = WorkoutExecutionCompatibilityAdapter(
      db: db,
      calendarRepo: CalendarRepository(db),
      preferenceRepo: ExercisePreferenceRepository(db),
    );

    await expectLater(
      adapter.resumeScheduledDraft(draft),
      throwsA(isA<ScheduledWorkoutRecoveryException>()),
    );
    expect(await db.select(db.workoutDrafts).get(), hasLength(1));
  });
}
