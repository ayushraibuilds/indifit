import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('B01-10 Backup v6 graph compatibility', () {
    test(
      'round-trips every B01 table and extended execution ancestry',
      () async {
        final source = AppDatabase.memory();
        final target = AppDatabase.memory();
        addTearDown(source.close);
        addTearDown(target.close);

        await _populateCompleteB01Graph(source);
        final sourcePrefs = await _prefs({'pref_remind_workout': true});
        final backup = await BackupData.createFromDatabase(source, sourcePrefs);
        final seededExercise = (await source.select(source.exercises).get())
            .firstWhere((exercise) => !exercise.isCustom);

        expect(backup.version, 6);
        expect(backup.programs, hasLength(1));
        expect(backup.programVersions, hasLength(1));
        expect(backup.programBlocks, hasLength(1));
        expect(backup.programWeeks, hasLength(1));
        expect(backup.sessionTemplates, hasLength(1));
        expect(backup.exercisePrescriptions, hasLength(1));
        expect(backup.scheduledSessionOccurrences, hasLength(2));
        expect(backup.occurrenceEvents, hasLength(1));
        expect(backup.equipmentProfiles, hasLength(1));
        expect(backup.equipmentProfileItems, hasLength(1));
        expect(backup.travelContexts, hasLength(1));
        expect(backup.travelContextOccurrences, hasLength(1));
        expect(backup.exerciseUserPreferences, hasLength(1));
        expect(backup.exerciseSetupValues, hasLength(1));
        expect(backup.exercisePersonalCues, hasLength(1));
        expect(backup.legacyRoutineProgramMappings, hasLength(1));
        expect(backup.workoutSessions.single.scheduledOccurrenceId, 'occ-1');
        expect(backup.workoutSets, hasLength(2));
        expect(
          backup.workoutSets.map((set) => set.exerciseId),
          containsAll([_customExerciseStableId, seededExercise.stableId]),
        );
        expect(backup.workoutDrafts.single.scheduledOccurrenceId, 'occ-repeat');
        expect(
          backup.workoutDrafts.single.executionSnapshotJson,
          _snapshotJson,
        );
        final envelope = BackupEnvelope.create(
          data: backup,
          payloadText: jsonEncode(backup.toJson()),
          isEncrypted: false,
        );
        expect(envelope.tableCounts['programs'], 1);
        expect(envelope.tableCounts['scheduled_session_occurrences'], 2);
        expect(envelope.tableCounts['travel_context_occurrences'], 1);
        expect(envelope.tableCounts['legacy_routine_program_mappings'], 1);

        // Force integer legacy IDs to be remapped during restore. The retained
        // mapping must follow the restored routine rather than the source ID.
        await target
            .into(target.workoutRoutines)
            .insert(
              WorkoutRoutinesCompanion.insert(name: 'Old Target', goal: 'x'),
            );
        final targetPrefs = await _prefs({'pref_remind_workout': false});
        await backup.restoreToDatabase(target, targetPrefs);

        expect(await target.select(target.programs).get(), hasLength(1));
        expect(await target.select(target.programVersions).get(), hasLength(1));
        expect(await target.select(target.programBlocks).get(), hasLength(1));
        expect(await target.select(target.programWeeks).get(), hasLength(1));
        expect(
          await target.select(target.sessionTemplates).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.exercisePrescriptions).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.scheduledSessionOccurrences).get(),
          hasLength(2),
        );
        expect(
          await target.select(target.occurrenceEvents).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.equipmentProfiles).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.equipmentProfileItems).get(),
          hasLength(1),
        );
        expect(await target.select(target.travelContexts).get(), hasLength(1));
        expect(
          await target.select(target.travelContextOccurrences).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.exerciseUserPreferences).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.exerciseSetupValues).get(),
          hasLength(1),
        );
        expect(
          await target.select(target.exercisePersonalCues).get(),
          hasLength(1),
        );

        final customExercises = (await target.select(target.exercises).get())
            .where((exercise) => exercise.isCustom)
            .toList();
        expect(customExercises.single.stableId, _customExerciseStableId);

        final session =
            (await target.select(target.workoutSessions).get()).single;
        expect(session.scheduledOccurrenceId, 'occ-1');
        expect(session.executionSnapshotJson, _snapshotJson);
        expect(session.executionTimezoneId, 'Asia/Kolkata');
        expect(session.completionKind, 'full');
        final sets = await target.select(target.workoutSets).get();
        expect(
          sets.map((set) => set.exerciseId),
          contains(_customExerciseStableId),
        );
        expect(
          sets.map((set) => set.exerciseId),
          contains(seededExercise.stableId),
        );
        final draft = (await target.select(target.workoutDrafts).get()).single;
        expect(draft.scheduledOccurrenceId, 'occ-repeat');
        expect(draft.executionSnapshotJson, _snapshotJson);
        expect(draft.draftSchemaVersion, 2);

        final settings = await target
            .select(target.trainingPlanSettings)
            .getSingle();
        expect(settings.activeProgramVersionId, 'version-1');
        expect(settings.defaultEquipmentProfileId, 'profile-1');

        final restoredRoutine =
            (await target.select(target.workoutRoutines).get()).single;
        final mapping = await target
            .select(target.legacyRoutineProgramMappings)
            .getSingle();
        expect(mapping.legacyRoutineId, restoredRoutine.id);
        expect(mapping.legacyRoutineId, isNot(1));
        expect(targetPrefs.getBool('pref_remind_workout'), isTrue);
      },
    );

    test(
      'rejects orphaned v6 graph before preferences or database mutate',
      () async {
        final source = AppDatabase.memory();
        final target = AppDatabase.memory();
        addTearDown(source.close);
        addTearDown(target.close);

        await _populateCompleteB01Graph(source);
        final valid = await BackupData.createFromDatabase(source);
        final payload =
            jsonDecode(jsonEncode(valid.toJson())) as Map<String, dynamic>;
        final occurrences = payload['scheduled_session_occurrences'] as List;
        (occurrences.first as Map<String, dynamic>)['programVersionId'] =
            'missing-version';
        final invalid = BackupData.fromJson(payload);

        await target
            .into(target.workoutRoutines)
            .insert(
              WorkoutRoutinesCompanion.insert(name: 'Sentinel', goal: 'x'),
            );
        final prefs = await _prefs({'water_logged': 2});
        invalid.userPreferences['water_logged'] = 9;

        await expectLater(
          invalid.restoreToDatabase(target, prefs),
          throwsA(isA<FormatException>()),
        );

        expect(
          (await target.select(target.workoutRoutines).get()).single.name,
          'Sentinel',
        );
        expect(prefs.getInt('water_logged'), 2);
      },
    );

    test(
      'rejects invalid B01 enum, event, civil date and IANA zone before mutation',
      () async {
        final source = AppDatabase.memory();
        final target = AppDatabase.memory();
        addTearDown(source.close);
        addTearDown(target.close);
        await _populateCompleteB01Graph(source);
        final valid = await BackupData.createFromDatabase(source);
        await target
            .into(target.workoutRoutines)
            .insert(
              WorkoutRoutinesCompanion.insert(name: 'Sentinel', goal: 'x'),
            );

        final mutations = <void Function(Map<String, dynamic>)>[
          (payload) =>
              (payload['scheduled_session_occurrences'] as List)
                      .first['status'] =
                  'unknown-status',
          (payload) =>
              (payload['occurrence_events'] as List).first['occurrenceId'] =
                  'missing-occurrence',
          (payload) =>
              (payload['scheduled_session_occurrences'] as List)
                      .first['originalLocalDate'] =
                  '2026-02-30',
          (payload) =>
              (payload['scheduled_session_occurrences'] as List)
                      .first['effectiveTimezoneId'] =
                  'Mars/Olympus',
        ];

        for (final mutate in mutations) {
          final payload =
              jsonDecode(jsonEncode(valid.toJson())) as Map<String, dynamic>;
          mutate(payload);
          final invalid = BackupData.fromJson(payload);
          await expectLater(
            invalid.restoreToDatabase(target),
            throwsA(isA<FormatException>()),
          );
          expect(
            (await target.select(target.workoutRoutines).get()).single.name,
            'Sentinel',
          );
        }
      },
    );
  });
}

const _customExerciseStableId = '11111111-1111-4111-8111-111111111111';
const _snapshotJson = '{"schemaVersion":1,"occurrenceId":"occ-1"}';

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> _populateCompleteB01Graph(AppDatabase db) async {
  final now = DateTime.utc(2026, 7, 29, 8);
  await db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          stableId: const Value(_customExerciseStableId),
          name: 'Custom Travel Press',
          muscleGroups: 'Chest',
          equipment: 'Dumbbell',
          difficulty: 'Intermediate',
          formCues: 'Controlled press',
          commonMistakes: 'Rushing the eccentric',
          isCustom: const Value(true),
        ),
      );

  final legacyRoutineId = await db
      .into(db.workoutRoutines)
      .insert(
        WorkoutRoutinesCompanion.insert(
          name: 'Retained Legacy Routine',
          goal: 'hypertrophy',
        ),
      );
  final legacyDayId = await db
      .into(db.routineDays)
      .insert(
        RoutineDaysCompanion.insert(
          routineId: legacyRoutineId,
          dayOfWeek: 1,
          name: 'Legacy Push',
        ),
      );
  await db
      .into(db.routineExercises)
      .insert(
        RoutineExercisesCompanion.insert(
          dayId: legacyDayId,
          exerciseName: 'Custom Travel Press',
          sets: 3,
          repsRange: '8-10',
          orderIndex: 0,
        ),
      );

  await db
      .into(db.programs)
      .insert(
        ProgramsCompanion.insert(
          id: 'program-1',
          name: 'Imported Program',
          goal: const Value('hypertrophy'),
          createdAtUtc: now,
        ),
      );
  await db
      .into(db.programVersions)
      .insert(
        ProgramVersionsCompanion.insert(
          id: 'version-1',
          programId: 'program-1',
          versionNumber: 1,
          status: 'published',
          origin: const Value('legacyImport'),
          createdAtUtc: now,
          publishedAtUtc: Value(now),
        ),
      );
  await db
      .into(db.programBlocks)
      .insert(
        ProgramBlocksCompanion.insert(
          id: 'block-1',
          programVersionId: 'version-1',
          ordinal: 1,
          name: 'Base',
        ),
      );
  await db
      .into(db.programWeeks)
      .insert(
        ProgramWeeksCompanion.insert(
          id: 'week-1',
          programVersionId: 'version-1',
          programBlockId: 'block-1',
          ordinalInBlock: 1,
          programWeekOrdinal: 1,
          isDeload: const Value(false),
        ),
      );
  await db
      .into(db.sessionTemplates)
      .insert(
        SessionTemplatesCompanion.insert(
          id: 'template-1',
          programWeekId: 'week-1',
          ordinal: 1,
          name: 'Push',
          plannedWeekday: 1,
        ),
      );
  await db
      .into(db.exercisePrescriptions)
      .insert(
        ExercisePrescriptionsCompanion.insert(
          id: 'prescription-1',
          sessionTemplateId: 'template-1',
          ordinal: 1,
          exerciseId: const Value(_customExerciseStableId),
          exerciseNameSnapshot: 'Custom Travel Press',
          plannedSets: 3,
          repsRange: '8-10',
        ),
      );
  await db
      .into(db.equipmentProfiles)
      .insert(
        EquipmentProfilesCompanion.insert(
          id: 'profile-1',
          name: 'Hotel Gym',
          defaultWeightIncrementKg: const Value(2.5),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await db
      .into(db.equipmentProfileItems)
      .insert(
        EquipmentProfileItemsCompanion.insert(
          id: 'profile-item-1',
          equipmentProfileId: 'profile-1',
          equipmentCode: 'dumbbell',
          weightIncrementKg: const Value(2.5),
        ),
      );
  await db
      .into(db.scheduledSessionOccurrences)
      .insert(
        ScheduledSessionOccurrencesCompanion.insert(
          id: 'occ-1',
          programVersionId: 'version-1',
          sessionTemplateId: 'template-1',
          programBlockOrdinal: 1,
          programWeekOrdinal: 1,
          sessionOrdinal: 1,
          originalLocalDate: '2026-07-27',
          originalTimezoneId: 'Asia/Kolkata',
          effectiveLocalDate: '2026-07-27',
          effectiveTimezoneId: 'Asia/Kolkata',
          status: const Value('completed'),
          progressionDisposition: const Value('satisfied'),
          executionSnapshotJson: const Value(_snapshotJson),
          startedAtUtc: Value(now),
          terminalAtUtc: Value(now.add(const Duration(hours: 1))),
          createdAtUtc: now,
        ),
      );
  await db
      .into(db.scheduledSessionOccurrences)
      .insert(
        ScheduledSessionOccurrencesCompanion.insert(
          id: 'occ-repeat',
          programVersionId: 'version-1',
          sessionTemplateId: 'template-1',
          programBlockOrdinal: 1,
          programWeekOrdinal: 1,
          sessionOrdinal: 1,
          repeatOrdinal: const Value(1),
          originalLocalDate: '2026-07-28',
          originalTimezoneId: 'Asia/Kolkata',
          effectiveLocalDate: '2026-07-28',
          effectiveTimezoneId: 'Asia/Kolkata',
          status: const Value('inProgress'),
          progressionDisposition: const Value('pending'),
          repeatPurpose: const Value('extra'),
          repeatedFromOccurrenceId: const Value('occ-1'),
          executionSnapshotJson: const Value(_snapshotJson),
          startedAtUtc: Value(now.add(const Duration(days: 1))),
          createdAtUtc: now,
        ),
      );
  await db
      .into(db.occurrenceEvents)
      .insert(
        OccurrenceEventsCompanion.insert(
          id: 'event-1',
          occurrenceId: 'occ-1',
          commandId: 'command-1',
          eventType: 'completed',
          fromStatus: const Value('inProgress'),
          toStatus: const Value('completed'),
          occurredAtUtc: now,
        ),
      );
  await db
      .into(db.trainingPlanSettings)
      .insertOnConflictUpdate(
        TrainingPlanSettingsCompanion.insert(
          id: const Value(1),
          activeProgramVersionId: const Value('version-1'),
          activeSinceLocalDate: const Value('2026-07-27'),
          activeSinceTimezoneId: const Value('Asia/Kolkata'),
          defaultEquipmentProfileId: const Value('profile-1'),
          updatedAtUtc: now,
        ),
      );
  await db
      .into(db.travelContexts)
      .insert(
        TravelContextsCompanion.insert(
          id: 'travel-1',
          startLocalDate: '2026-07-27',
          endLocalDate: '2026-07-28',
          timezoneId: 'Asia/Kolkata',
          equipmentProfileId: 'profile-1',
          createdAtUtc: now,
        ),
      );
  await db
      .into(db.travelContextOccurrences)
      .insert(
        TravelContextOccurrencesCompanion.insert(
          travelContextId: 'travel-1',
          occurrenceId: 'occ-1',
          confirmedAtUtc: now,
        ),
      );
  await db
      .into(db.exerciseUserPreferences)
      .insert(
        ExerciseUserPreferencesCompanion.insert(
          id: 'preference-1',
          identityKey: 'exercise:$_customExerciseStableId',
          exerciseId: const Value(_customExerciseStableId),
          generalNote: const Value('Use the marked dumbbells.'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await db
      .into(db.exerciseSetupValues)
      .insert(
        ExerciseSetupValuesCompanion.insert(
          id: 'setup-1',
          exerciseUserPreferenceId: 'preference-1',
          ordinal: 1,
          label: 'Bench angle',
          value: '30°',
        ),
      );
  await db
      .into(db.exercisePersonalCues)
      .insert(
        ExercisePersonalCuesCompanion.insert(
          id: 'cue-1',
          exerciseUserPreferenceId: 'preference-1',
          ordinal: 1,
          cueText: 'Brace before each press.',
        ),
      );
  await db
      .into(db.legacyRoutineProgramMappings)
      .insert(
        LegacyRoutineProgramMappingsCompanion.insert(
          legacyRoutineId: Value(legacyRoutineId),
          programId: 'program-1',
          programVersionId: 'version-1',
          importedAtUtc: now,
        ),
      );

  final sessionId = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Completed Push',
          totalVolume: 1200,
          durationSeconds: 1800,
          estimatedCalories: 250,
          completedAt: Value(now),
          scheduledOccurrenceId: const Value('occ-1'),
          executionSnapshotJson: const Value(_snapshotJson),
          executionTimezoneId: const Value('Asia/Kolkata'),
          completionKind: const Value('full'),
        ),
      );
  final seededExercise = (await db.select(db.exercises).get()).firstWhere(
    (exercise) => !exercise.isCustom,
  );
  await db
      .into(db.workoutSets)
      .insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseName: 'Custom Travel Press',
          weight: 20,
          reps: 10,
          setNumber: 1,
          exerciseId: const Value(_customExerciseStableId),
        ),
      );
  await db
      .into(db.workoutSets)
      .insert(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseName: seededExercise.name,
          weight: 30,
          reps: 8,
          setNumber: 2,
          exerciseId: Value(seededExercise.stableId),
        ),
      );
  await db
      .into(db.workoutDrafts)
      .insert(
        WorkoutDraftsCompanion.insert(
          routineName: 'Repeat Push',
          currentExerciseIndex: 0,
          currentSetIndex: 0,
          elapsedSeconds: 120,
          loggedSetsJson: '[]',
          scheduledOccurrenceId: const Value('occ-repeat'),
          executionSnapshotJson: const Value(_snapshotJson),
          draftSchemaVersion: const Value(2),
        ),
      );
}
