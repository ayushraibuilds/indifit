import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/workout_execution_compatibility_adapter.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository programRepo;
  late ProgramActivationCoordinator activationCoordinator;
  late CalendarRepository calendarRepo;
  late WorkoutRepository workoutRepo;
  late ExercisePreferenceRepository preferenceRepo;
  late WorkoutExecutionCompatibilityAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    programRepo = ProgramRepository(db);
    activationCoordinator = ProgramActivationCoordinator(db);
    calendarRepo = CalendarRepository(db);
    workoutRepo = WorkoutRepository(db);
    preferenceRepo = ExercisePreferenceRepository(db);
    adapter = WorkoutExecutionCompatibilityAdapter(
      db: db,
      calendarRepo: calendarRepo,
      workoutRepo: workoutRepo,
      preferenceRepo: preferenceRepo,
    );

    // Seed exercise for FK validation
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('ex-bench-press-stable-id'),
            name: 'Flat Barbell Bench Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Touch chest',
            commonMistakes: 'Elbow flare',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-09 Execution Bridge & Scheduled Workout Completion Tests', () {
    Future<String> setupActivatedOccurrence() async {
      final programId = await programRepo.createProgram(
        name: 'Hypertrophy Bridge Program',
        blocks: [
          ProgramBlockInput(
            name: 'Block 1',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Chest & Triceps Focus',
                    ordinal: 0,
                    plannedWeekday: 1,
                    prescriptions: [
                      const ExercisePrescriptionInput(
                        exerciseId: 'ex-bench-press-stable-id',
                        exerciseNameSnapshot: 'Flat Barbell Bench Press',
                        plannedSets: 4,
                        repsRange: '8-10',
                        ordinal: 0,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final v1 = (await programRepo.getVersionsForProgram(programId)).first;

      final result = await activationCoordinator.activate(
        ActivateProgramVersionCommand(
          programVersionId: v1.id,
          activationLocalDate: '2026-08-03',
          timezoneId: 'UTC',
          commandId: 'cmd-activate-bridge',
        ),
      );

      return result.occurrences.first.id;
    }

    test(
      '1. Launches scheduled occurrence, creates frozen execution snapshot & draft',
      () async {
        final occId = await setupActivatedOccurrence();

        final launchData = await adapter.startScheduledOccurrence(
          occurrenceId: occId,
          confirmedOutsideEffectiveDate: true,
        );

        expect(launchData.occurrenceId, equals(occId));
        expect(
          launchData.routineName,
          equals('Hypertrophy Bridge Program — Chest & Triceps Focus'),
        );
        expect(
          launchData.executionSnapshotJson,
          contains('Flat Barbell Bench Press'),
        );

        // Check occurrence state is inProgress
        final occ = await calendarRepo.getOccurrence(occId);
        expect(occ, isNotNull);
        expect(occ!.status, equals('inProgress'));
        expect(
          occ.executionSnapshotJson,
          equals(launchData.executionSnapshotJson),
        );

        // Check active workout draft is created and linked to occurrenceId
        final draft = await workoutRepo.getActiveDraft();
        expect(draft, isNotNull);
        expect(draft!.scheduledOccurrenceId, equals(occId));
      },
    );

    test(
      '2. Starting a second occurrence while a draft exists throws exception',
      () async {
        final occId = await setupActivatedOccurrence();

        await adapter.startScheduledOccurrence(
          occurrenceId: occId,
          confirmedOutsideEffectiveDate: true,
        );

        // Attempt starting again or starting another occurrence fails
        expect(
          () => adapter.startScheduledOccurrence(
            occurrenceId: occId,
            confirmedOutsideEffectiveDate: true,
          ),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
      },
    );

    test(
      '3 & 4. Finalizes scheduled session atomically in 1 transaction and handles commandId idempotency',
      () async {
        final occId = await setupActivatedOccurrence();

        await adapter.startScheduledOccurrence(
          occurrenceId: occId,
          confirmedOutsideEffectiveDate: true,
        );

        final commandId = 'cmd-complete-unique-123';

        final sets = [
          WorkoutSetsCompanion.insert(
            sessionId: 0,
            exerciseName: 'Flat Barbell Bench Press',
            weight: 85.0,
            reps: 8,
            setNumber: 1,
            isPr: const Value(true),
            rpe: const Value(8),
          ),
        ];

        // Attempt 1: Completes session
        final sessionId1 = await adapter.finalizeScheduledWorkoutSession(
          occurrenceId: occId,
          commandId: commandId,
          name: 'Chest & Triceps Focus',
          volume: 680.0,
          durationSeconds: 2400,
          calories: 250,
          sets: sets,
        );

        expect(sessionId1, greaterThan(0));

        // 1. WorkoutSession row created and linked to scheduledOccurrenceId
        final session = await (db.select(
          db.workoutSessions,
        )..where((t) => t.id.equals(sessionId1))).getSingle();
        expect(session.name, equals('Chest & Triceps Focus'));
        expect(session.scheduledOccurrenceId, equals(occId));

        // 2. WorkoutSet row created
        final loggedSets = await (db.select(
          db.workoutSets,
        )..where((t) => t.sessionId.equals(sessionId1))).get();
        expect(loggedSets.length, equals(1));
        expect(
          loggedSets.first.exerciseName,
          equals('Flat Barbell Bench Press'),
        );

        // 3. Occurrence status updated to completed
        final occ = await calendarRepo.getOccurrence(occId);
        expect(occ!.status, equals('completed'));
        expect(occ.progressionDisposition, equals('satisfied'));

        // 4. Active draft deleted
        final activeDraft = await workoutRepo.getActiveDraft();
        expect(activeDraft, isNull);

        // Attempt 2 (Idempotent retry with SAME commandId): Returns SAME sessionId without creating duplicate records
        final sessionId2 = await adapter.finalizeScheduledWorkoutSession(
          occurrenceId: occId,
          commandId: commandId,
          name: 'Chest & Triceps Focus',
          volume: 680.0,
          durationSeconds: 2400,
          calories: 250,
          sets: sets,
        );

        expect(sessionId2, equals(sessionId1));

        final allSessions = await db.select(db.workoutSessions).get();
        expect(allSessions.length, equals(1)); // Still exactly 1 session
      },
    );

    test(
      '5. Discarding started occurrence restores state and deletes draft',
      () async {
        final occId = await setupActivatedOccurrence();

        await adapter.startScheduledOccurrence(
          occurrenceId: occId,
          confirmedOutsideEffectiveDate: true,
        );

        expect(await workoutRepo.getActiveDraft(), isNotNull);

        await adapter.discardScheduledOccurrenceDraft(occurrenceId: occId);

        // Draft deleted
        expect(await workoutRepo.getActiveDraft(), isNull);

        // Occurrence status reset
        final occ = await calendarRepo.getOccurrence(occId);
        expect(occ!.status, equals('planned'));
      },
    );

    test(
      '6. Unscheduled manual workout session logging remains 100% backward compatible',
      () async {
        final sets = [
          WorkoutSetsCompanion.insert(
            sessionId: 0,
            exerciseName: 'Dumbbell Curl',
            weight: 15.0,
            reps: 12,
            setNumber: 1,
          ),
        ];

        final sessionId = await workoutRepo.logSession(
          name: 'Manual Bicep Log',
          volume: 180.0,
          durationSeconds: 900,
          calories: 80,
          sets: sets,
        );

        final session = await (db.select(
          db.workoutSessions,
        )..where((t) => t.id.equals(sessionId))).getSingle();
        expect(session.name, equals('Manual Bicep Log'));
        expect(
          session.scheduledOccurrenceId,
          isNull,
        ); // Null occurrence link for unscheduled logs
      },
    );
  });
}
