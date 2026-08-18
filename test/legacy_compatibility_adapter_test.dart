import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/legacy_program_compatibility_adapter.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorkoutRepository workoutRepo;
  late LegacyProgramCompatibilityAdapter legacyAdapter;
  late ProgramRepository programRepo;
  late ProgramActivationCoordinator coordinator;

  setUp(() {
    db = AppDatabase.memory();
    workoutRepo = WorkoutRepository(db);
    legacyAdapter = LegacyProgramCompatibilityAdapter(db);
    programRepo = ProgramRepository(db);
    coordinator = ProgramActivationCoordinator(
      db,
      dates: LocalScheduleDateService(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-13 Legacy Compatibility Adapter & Single Authority Tests', () {
    test(
      '1. Single authority resolution falls back to greatest routine ID when no B01 version is active',
      () async {
        // 1. Empty database -> none
        var selection = await legacyAdapter.resolveActivePlanSelection();
        expect(selection.type, equals(ActivePlanType.none));

        // 2. Insert two legacy routines (routine #1 and routine #2)
        final r1 = await workoutRepo.saveRoutine(
          name: 'Legacy Upper/Lower 1',
          goal: 'Hypertrophy',
          days: [
            RoutineDayWithExercises(
              dayName: 'Upper Day',
              dayOfWeek: 1,
              isRestDay: false,
              exercises: [
                RoutineExerciseInput(
                  name: 'Barbell Bench Press',
                  sets: 3,
                  repsRange: '8-10',
                ),
              ],
            ),
          ],
        );

        final r2 = await workoutRepo.saveRoutine(
          name: 'Legacy Push/Pull 2',
          goal: 'Strength',
          days: [
            RoutineDayWithExercises(
              dayName: 'Push Day',
              dayOfWeek: 2,
              isRestDay: false,
              exercises: [
                RoutineExerciseInput(
                  name: 'Overhead Press',
                  sets: 4,
                  repsRange: '5',
                ),
              ],
            ),
          ],
        );

        expect(r2, greaterThan(r1));

        // Active plan selection must select legacy routine #2 (greatest ID)
        selection = await legacyAdapter.resolveActivePlanSelection();
        expect(selection.type, equals(ActivePlanType.legacyRoutine));
        expect(selection.legacyRoutineId, equals(r2));
      },
    );

    test(
      '2. Single authority resolution prioritizes active B01 ProgramVersion when activated',
      () async {
        // Insert legacy routine
        await workoutRepo.saveRoutine(
          name: 'Legacy Routine',
          goal: 'Maintenance',
          days: [
            RoutineDayWithExercises(
              dayName: 'Day 1',
              dayOfWeek: 1,
              isRestDay: false,
              exercises: [],
            ),
          ],
        );

        // 0. Seed exercise
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                stableId: Value('ex-squat-uuid'),
                name: 'Squat',
                muscleGroups: 'Legs',
                equipment: 'barbell',
                difficulty: 'Intermediate',
                formCues: 'Break at hips',
                commonMistakes: 'Knees caving in',
              ),
            );

        // Create and activate a B01 Program Version
        final progId = await programRepo.createProgram(
          name: 'B01 Hypertrophy Plan',
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
                      name: 'Day A',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseId: 'ex-squat-uuid',
                          exerciseNameSnapshot: 'Squat',
                          plannedSets: 3,
                          repsRange: '5',
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

        final v1 = (await programRepo.getVersionsForProgram(progId)).first;
        await coordinator.activate(
          ActivateProgramVersionCommand(
            programVersionId: v1.id,
            commandId: 'cmd-act-13',
            activationLocalDate: '2026-08-03',
            timezoneId: 'Asia/Kolkata',
          ),
        );

        // Single authority resolution must prioritize the active B01 program version
        final selection = await legacyAdapter.resolveActivePlanSelection();
        expect(selection.type, equals(ActivePlanType.b01Program));
        expect(selection.programVersionId, equals(v1.id));
      },
    );

    test(
      '3. Saving legacy routine syncs legacyImport ProgramVersion without silent program activation',
      () async {
        final routineId = await workoutRepo.saveRoutine(
          name: 'Editable Legacy Routine',
          goal: 'Fat Loss',
          notes: 'Keep rest intervals short',
          days: [
            RoutineDayWithExercises(
              dayName: 'Leg Day',
              dayOfWeek: 3,
              isRestDay: false,
              exercises: [
                RoutineExerciseInput(name: 'Squat', sets: 4, repsRange: '10'),
              ],
            ),
          ],
        );

        // Verify legacy tables updated
        final legacyDetails = await workoutRepo.getRoutineDetails(routineId);
        expect(legacyDetails.length, equals(1));
        expect(
          (legacyDetails.first['exercises'] as List<RoutineExercise>)
              .first
              .exerciseName,
          equals('Squat'),
        );

        // Verify B01 program version snapshot was created with status 'draft' / origin 'legacyImport'
        final mappings = await (db.select(
          db.legacyRoutineProgramMappings,
        )..where((t) => t.legacyRoutineId.equals(routineId))).get();
        expect(mappings.length, equals(1));
        final version =
            await (db.select(db.programVersions)
                  ..where((t) => t.id.equals(mappings.first.programVersionId)))
                .getSingle();
        expect(version.status, equals('draft'));
        expect(version.origin, equals('legacyImport'));

        // Verify NO active version was assigned in settings
        final settings = await (db.select(
          db.trainingPlanSettings,
        )).getSingleOrNull();
        expect(settings?.activeProgramVersionId, isNull);

        // Verify NO occurrences materialized
        final occurrences = await (db.select(
          db.scheduledSessionOccurrences,
        )).get();
        expect(occurrences, isEmpty);
      },
    );

    test(
      '4. Unscheduled workout logging preserves null ancestry and exact-name history queries',
      () async {
        // 1. Log an unscheduled session
        final sessionId = await workoutRepo.logSession(
          name: 'Unscheduled Full Body',
          volume: 1500.0,
          durationSeconds: 2700,
          calories: 300,
          sets: [
            WorkoutSetsCompanion.insert(
              sessionId: 1, // Will be overridden by logSession
              exerciseName: 'Incline Dumbbell Press',
              weight: 30.0,
              reps: 10,
              setNumber: 1,
            ),
          ],
        );

        // Verify null scheduled occurrence ancestry
        final sessionRow = await (db.select(
          db.workoutSessions,
        )..where((t) => t.id.equals(sessionId))).getSingle();
        expect(sessionRow.scheduledOccurrenceId, isNull);

        // Verify exact name query set prefill
        final latestSets = await workoutRepo.getLatestSetsForExercise(
          'Incline Dumbbell Press',
        );
        expect(latestSets.length, equals(1));
        expect(latestSets.first.weight, equals(30.0));
        expect(latestSets.first.reps, equals(10));
      },
    );

    test(
      '5. Editing a legacy routine cannot rewrite its published imported snapshot',
      () async {
        final routineId = await workoutRepo.saveRoutine(
          name: 'Legacy Rest Split',
          goal: 'Maintenance',
          days: [
            RoutineDayWithExercises(
              dayName: 'Legs',
              dayOfWeek: DateTime.monday,
              isRestDay: false,
              exercises: [
                RoutineExerciseInput(
                  name: 'Barbell Squat',
                  sets: 3,
                  repsRange: '5',
                ),
              ],
            ),
          ],
        );
        final mapping =
            await (db.select(db.legacyRoutineProgramMappings)
                  ..where((table) => table.legacyRoutineId.equals(routineId)))
                .getSingle();

        await coordinator.activate(
          ActivateProgramVersionCommand(
            programVersionId: mapping.programVersionId,
            commandId: 'activate-imported-snapshot',
            activationLocalDate: '2026-08-03',
            timezoneId: 'Asia/Kolkata',
          ),
        );

        await expectLater(
          workoutRepo.saveRoutine(
            routineId: routineId,
            name: 'Attempted Legacy Rewrite',
            goal: 'Maintenance',
            days: [
              RoutineDayWithExercises(
                dayName: 'Changed Day',
                dayOfWeek: DateTime.tuesday,
                isRestDay: true,
                exercises: const [],
              ),
            ],
          ),
          throwsA(isA<StateError>()),
        );

        final legacy = await (db.select(
          db.workoutRoutines,
        )..where((table) => table.id.equals(routineId))).getSingle();
        final version =
            await (db.select(db.programVersions)
                  ..where((table) => table.id.equals(mapping.programVersionId)))
                .getSingle();
        expect(legacy.name, equals('Legacy Rest Split'));
        expect(version.status, equals('published'));
      },
    );

    test(
      '6. An invalid active-version pointer never falls back to a legacy routine',
      () async {
        final routineId = await workoutRepo.saveRoutine(
          name: 'Fallback Must Not Win',
          goal: 'Maintenance',
          days: const [],
        );
        final mapping =
            await (db.select(db.legacyRoutineProgramMappings)
                  ..where((table) => table.legacyRoutineId.equals(routineId)))
                .getSingle();
        await (db.update(
          db.trainingPlanSettings,
        )..where((table) => table.id.equals(1))).write(
          TrainingPlanSettingsCompanion(
            activeProgramVersionId: Value(mapping.programVersionId),
            updatedAtUtc: Value(DateTime.now().toUtc()),
          ),
        );

        await expectLater(
          legacyAdapter.resolveActivePlanSelection(),
          throwsA(isA<StateError>()),
        );
      },
    );

    for (final trainingDays in const [3, 4, 5]) {
      test(
        '7.$trainingDays consumer $trainingDays-day template activates canonical Training and Calendar once',
        () async {
          final planName = trainingDays == 3
              ? 'Suggested PPL'
              : '$trainingDays-Day Device Template';
          final routineId = await workoutRepo.saveRoutine(
            name: planName,
            goal: 'General fitness',
            days: [
              for (var day = 1; day <= 7; day++)
                RoutineDayWithExercises(
                  dayName: day <= trainingDays ? 'Training $day' : 'Rest $day',
                  dayOfWeek: day,
                  isRestDay: day > trainingDays,
                  exercises: day <= trainingDays
                      ? [
                          RoutineExerciseInput(
                            name: 'Fixture Exercise $day',
                            sets: 3,
                            repsRange: '8-12',
                          ),
                        ]
                      : const [],
                ),
            ],
          );
          final dates = LocalScheduleDateService(
            nowUtc: () => DateTime.utc(2026, 8, 3, 6),
          );
          final activationCoordinator = ProgramActivationCoordinator(
            db,
            dates: dates,
          );
          final readRepository = CalendarReadRepository(db, dates: dates);
          final invalidated = trainingDays == 3
              ? readRepository
                    .watchInvalidation(
                      startLocalDate: '2026-08-03',
                      endLocalDate: '2026-08-09',
                      timezoneId: 'Asia/Kolkata',
                    )
                    .first
                    .timeout(const Duration(seconds: 2))
              : null;
          // Let each Drift watch establish and skip its initial snapshot. The
          // following activation must then notify an already-mounted reader.
          await Future<void>.delayed(Duration.zero);

          final first = await legacyAdapter.activateLegacyRoutineAsCanonical(
            legacyRoutineId: routineId,
            activationCoordinator: activationCoordinator,
            dates: dates,
            timezoneId: 'Asia/Kolkata',
            activationLocalDate: '2026-08-03',
            commandId: 'activate-device-template-$trainingDays',
          );
          final replay = await legacyAdapter.activateLegacyRoutineAsCanonical(
            legacyRoutineId: routineId,
            activationCoordinator: activationCoordinator,
            dates: dates,
            timezoneId: 'Asia/Kolkata',
            activationLocalDate: '2026-08-03',
            commandId: 'activate-device-template-$trainingDays',
          );
          await invalidated;

          expect(first.occurrences, hasLength(trainingDays));
          expect(first.occurrences.map((row) => row.effectiveLocalDate), [
            '2026-08-03',
            '2026-08-04',
            '2026-08-05',
            if (trainingDays >= 4) '2026-08-06',
            if (trainingDays >= 5) '2026-08-07',
          ]);
          expect(replay.wasIdempotent, isTrue);
          expect(replay.occurrences, hasLength(trainingDays));
          expect(
            await db.select(db.scheduledSessionOccurrences).get(),
            hasLength(trainingDays),
          );

          final selection = await legacyAdapter.resolveActivePlanSelection();
          expect(selection.type, ActivePlanType.b01Program);
          expect(selection.programVersionId, first.programVersionId);

          final calendar = await readRepository.readSnapshot(
            startLocalDate: '2026-08-03',
            endLocalDate: '2026-08-09',
            timezoneId: 'Asia/Kolkata',
          );
          expect(calendar.activeProgramName, planName);
          expect(calendar.rangeOccurrences, hasLength(trainingDays));
          expect(calendar.rangeOccurrences.map((item) => item.template.name), [
            for (var day = 1; day <= trainingDays; day++) 'Training $day',
          ]);
        },
      );
    }
  });
}
