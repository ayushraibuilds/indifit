import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/services/b02_occurrence_snapshot_customizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PV1-PLAN-02 consumer customization repository authority', () {
    late AppDatabase db;
    late CalendarRepository calendar;
    late ProgramRepository programs;
    late EquipmentProfileRepository equipmentRepo;
    late LocalScheduleDateService dates;
    late String versionId;
    late String benchPrescriptionId;
    late String templateAId;
    late String templateBId;

    setUp(() async {
      db = AppDatabase.memory();
      final now = DateTime.utc(2026, 8, 18, 8); // Tuesday
      dates = LocalScheduleDateService(nowUtc: () => now);
      await db.batch(
        (batch) => batch.insertAll(db.exercises, [
          _exercise('bench-press', 'Bench Press', 'Barbell'),
          _exercise('cable-row', 'Cable Row', 'Cable'),
          _exercise('dumbbell-press', 'Dumbbell Press', 'Dumbbell'),
          _exercise('push-up', 'Push Up', 'Bodyweight'),
          _exercise('exotic-machine', 'Exotic Lift', 'AntiGravityDevice'),
        ]),
      );

      programs = ProgramRepository(db);
      final programId = await programs.createProgram(
        name: 'Customization Test Plan',
        blocks: [
          ProgramBlockInput(
            name: 'Block 1',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                name: 'Week 1',
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'Upper Body',
                    ordinal: 0,
                    plannedWeekday: DateTime.tuesday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        id: 'presc-bench',
                        exerciseId: 'bench-press',
                        exerciseNameSnapshot: 'Bench Press',
                        plannedSets: 3,
                        repsRange: '8–10',
                        ordinal: 0,
                      ),
                      ExercisePrescriptionInput(
                        id: 'presc-row',
                        exerciseId: 'cable-row',
                        exerciseNameSnapshot: 'Cable Row',
                        plannedSets: 3,
                        repsRange: '10–12',
                        ordinal: 1,
                      ),
                    ],
                  ),
                  SessionTemplateInput(
                    name: 'Lower Body',
                    ordinal: 1,
                    plannedWeekday: DateTime.thursday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        id: 'presc-pushup',
                        exerciseId: 'push-up',
                        exerciseNameSnapshot: 'Push Up',
                        plannedSets: 3,
                        repsRange: '12–15',
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

      final versions = await programs.getVersionsForProgram(programId);
      versionId = versions.single.id;

      final versionDetail = await programs.getProgramVersionDetail(versionId);
      templateAId = versionDetail!.sessionTemplates
          .firstWhere((t) => t.name == 'Upper Body')
          .id;
      templateBId = versionDetail.sessionTemplates
          .firstWhere((t) => t.name == 'Lower Body')
          .id;
      benchPrescriptionId = 'presc-bench';

      await ProgramActivationCoordinator(
        db,
        dates: dates,
        nowUtc: () => now,
      ).activate(
        ActivateProgramVersionCommand(
          programVersionId: versionId,
          commandId: 'activate::$versionId',
          activationLocalDate: '2026-08-18',
          timezoneId: 'UTC',
        ),
      );

      // Insert two additional occurrences for Upper Body to simulate multiple future occurrences of the template
      await db.batch((batch) {
        batch.insertAll(db.scheduledSessionOccurrences, [
          ScheduledSessionOccurrencesCompanion.insert(
            id: 'occ-upper-2',
            programVersionId: versionId,
            sessionTemplateId: templateAId,
            programBlockOrdinal: 0,
            programWeekOrdinal: 0,
            sessionOrdinal: 0,
            repeatOrdinal: const Value(1),
            originalLocalDate: '2026-08-25',
            originalTimezoneId: 'UTC',
            effectiveLocalDate: '2026-08-25',
            effectiveTimezoneId: 'UTC',
            createdAtUtc: now,
          ),
          ScheduledSessionOccurrencesCompanion.insert(
            id: 'occ-upper-3',
            programVersionId: versionId,
            sessionTemplateId: templateAId,
            programBlockOrdinal: 0,
            programWeekOrdinal: 0,
            sessionOrdinal: 0,
            repeatOrdinal: const Value(2),
            originalLocalDate: '2026-09-01',
            originalTimezoneId: 'UTC',
            effectiveLocalDate: '2026-09-01',
            effectiveTimezoneId: 'UTC',
            createdAtUtc: now,
          ),
        ]);
      });

      calendar = CalendarRepository(db, dates: dates, nowUtc: () => now);
      equipmentRepo = EquipmentProfileRepository(db);
    });

    tearDown(() => db.close());

    test('cascades customization across all future unstarted occurrences of same template', () async {
      final allOccurrences = await calendar.getOccurrencesInLocalDateRange(
        startLocalDate: '2026-08-18',
        endLocalDate: '2026-09-10',
      );

      final upperOccurrences = allOccurrences
          .where((o) => o.sessionTemplateId == templateAId)
          .toList()
        ..sort((a, b) => a.effectiveLocalDate.compareTo(b.effectiveLocalDate));
      final lowerOccurrences = allOccurrences
          .where((o) => o.sessionTemplateId == templateBId)
          .toList();

      expect(upperOccurrences.length, 3);
      expect(lowerOccurrences.length, 1);

      final firstUpper = upperOccurrences.first;
      final baseSnapshot = await calendar.readWorkoutPreviewSnapshot(firstUpper.id);

      final result = await calendar.customizeFutureOccurrences(
        CustomizeFutureOccurrencesCommand(
          occurrenceId: firstUpper.id,
          commandId: 'cascade::upper::1',
          expectedStatus: OccurrenceStatus.planned,
          baseSnapshotJson: baseSnapshot,
          changes: [
            OccurrenceExerciseCustomization(
              prescriptionId: benchPrescriptionId,
              replacementExerciseId: 'dumbbell-press',
              plannedSets: 4,
              repsRange: '6–8',
            ),
          ],
        ),
      );

      expect(result.affectedCount, 3);
      expect(result.sourceResult.occurrence.id, firstUpper.id);
      expect(result.sourceResult.event.eventType, 'customized');
      final metadata = jsonDecode(result.sourceResult.event.metadataJson!) as Map<String, dynamic>;
      expect(metadata['cascade'], true);
      expect(metadata['targetCount'], 3);

      // Verify all 3 Upper Body occurrences have the customized snapshot
      for (final occ in upperOccurrences) {
        final reloaded = (await calendar.getOccurrence(occ.id))!;
        expect(reloaded.executionSnapshotJson, isNotNull);
        final decoded = jsonDecode(reloaded.executionSnapshotJson!) as Map<String, dynamic>;
        expect(decoded['occurrenceId'], occ.id);
        final presc = (decoded['prescriptions'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['id'] == benchPrescriptionId);
        expect(presc['exerciseId'], 'dumbbell-press');
        expect(presc['exerciseNameSnapshot'], 'Dumbbell Press');
        expect(presc['expectedExerciseId'], 'bench-press');
        expect(presc['plannedSets'], 4);
        expect(presc['repsRange'], '6–8');
      }

      // Verify Lower Body occurrences were NOT modified
      for (final occ in lowerOccurrences) {
        final reloaded = (await calendar.getOccurrence(occ.id))!;
        expect(reloaded.executionSnapshotJson, isNull);
      }

      // Verify published catalog version remains immutable
      final catalogDetail = await programs.getProgramVersionDetail(versionId);
      final catalogBench = catalogDetail!.exercisePrescriptions.firstWhere(
        (p) => p.id == benchPrescriptionId,
      );
      expect(catalogBench.exerciseId, 'bench-press');
      expect(catalogBench.plannedSets, 3);
    });

    test('cascade overwrites prior individual tweaks on upcoming targets', () async {
      final allOccurrences = await calendar.getOccurrencesInLocalDateRange(
        startLocalDate: '2026-08-18',
        endLocalDate: '2026-09-10',
      );

      final upperOccurrences = allOccurrences
          .where((o) => o.sessionTemplateId == templateAId)
          .toList()
        ..sort((a, b) => a.effectiveLocalDate.compareTo(b.effectiveLocalDate));

      final occ1 = upperOccurrences[0];
      final occ2 = upperOccurrences[1];
      final occ3 = upperOccurrences[2];

      // Give occ3 an individual prior tweak (e.g. plannedSets = 5)
      final base3 = await calendar.readWorkoutPreviewSnapshot(occ3.id);
      await calendar.customize(
        CustomizeOccurrenceCommand(
          occurrenceId: occ3.id,
          commandId: 'individual::occ3',
          expectedStatus: OccurrenceStatus.planned,
          baseSnapshotJson: base3,
          changes: [
            OccurrenceExerciseCustomization(
              prescriptionId: benchPrescriptionId,
              plannedSets: 5,
            ),
          ],
        ),
      );

      // Verify occ3 has 5 sets
      final occ3BeforeCascade = (await calendar.getOccurrence(occ3.id))!;
      final decodedBefore = jsonDecode(occ3BeforeCascade.executionSnapshotJson!) as Map<String, dynamic>;
      final prescBefore = (decodedBefore['prescriptions'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['id'] == benchPrescriptionId);
      expect(prescBefore['plannedSets'], 5);

      // Now cascade customize from occ2 onwards: replace Bench with Dumbbell Press, 4 sets
      final base2 = await calendar.readWorkoutPreviewSnapshot(occ2.id);
      final result = await calendar.customizeFutureOccurrences(
        CustomizeFutureOccurrencesCommand(
          occurrenceId: occ2.id,
          commandId: 'cascade::from::occ2',
          expectedStatus: OccurrenceStatus.planned,
          baseSnapshotJson: base2,
          changes: [
            OccurrenceExerciseCustomization(
              prescriptionId: benchPrescriptionId,
              replacementExerciseId: 'dumbbell-press',
              plannedSets: 4,
            ),
          ],
        ),
      );

      // Affected count is 2 (occ2 and occ3)
      expect(result.affectedCount, 2);

      // occ1 was earlier than occ2, so untouched
      final occ1After = (await calendar.getOccurrence(occ1.id))!;
      expect(occ1After.executionSnapshotJson, isNull);

      // occ2 has the new cascade
      final occ2After = (await calendar.getOccurrence(occ2.id))!;
      final decoded2 = jsonDecode(occ2After.executionSnapshotJson!) as Map<String, dynamic>;
      final presc2 = (decoded2['prescriptions'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['id'] == benchPrescriptionId);
      expect(presc2['exerciseId'], 'dumbbell-press');
      expect(presc2['plannedSets'], 4);

      // occ3's prior tweak (5 sets) was cleanly overwritten by the cascade (Dumbbell Press, 4 sets)
      final occ3After = (await calendar.getOccurrence(occ3.id))!;
      final decoded3 = jsonDecode(occ3After.executionSnapshotJson!) as Map<String, dynamic>;
      final presc3 = (decoded3['prescriptions'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['id'] == benchPrescriptionId);
      expect(presc3['exerciseId'], 'dumbbell-press');
      expect(presc3['plannedSets'], 4);
    });

    test('historical frozen execution is never mutated by cascade and cannot be customized', () async {
      final allOccurrences = await calendar.getOccurrencesInLocalDateRange(
        startLocalDate: '2026-08-18',
        endLocalDate: '2026-09-10',
      );

      final upperOccurrences = allOccurrences
          .where((o) => o.sessionTemplateId == templateAId)
          .toList()
        ..sort((a, b) => a.effectiveLocalDate.compareTo(b.effectiveLocalDate));

      final occ1 = upperOccurrences[0];
      final occ2 = upperOccurrences[1];

      // Mark occ1 as completed
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(occ1.id)))
          .write(
            const ScheduledSessionOccurrencesCompanion(
              status: Value('completed'),
            ),
          );

      // Attempting to customize occ1 throws InvalidOccurrenceTransitionException
      final base1 = await calendar.readWorkoutPreviewSnapshot(occ1.id);
      expect(
        () => calendar.customizeFutureOccurrences(
          CustomizeFutureOccurrencesCommand(
            occurrenceId: occ1.id,
            commandId: 'illegal::occ1',
            expectedStatus: OccurrenceStatus.planned,
            baseSnapshotJson: base1,
            changes: [
              OccurrenceExerciseCustomization(
                prescriptionId: benchPrescriptionId,
                plannedSets: 4,
              ),
            ],
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );

      // Customizing from occ2 only touches unstarted occ2 and occ3
      final base2 = await calendar.readWorkoutPreviewSnapshot(occ2.id);
      final result = await calendar.customizeFutureOccurrences(
        CustomizeFutureOccurrencesCommand(
          occurrenceId: occ2.id,
          commandId: 'cascade::occ2',
          expectedStatus: OccurrenceStatus.planned,
          baseSnapshotJson: base2,
          changes: [
            OccurrenceExerciseCustomization(
              prescriptionId: benchPrescriptionId,
              plannedSets: 4,
            ),
          ],
        ),
      );

      expect(result.affectedCount, 2);

      // Verify occ1 remained strictly completed and unmutated
      final occ1Reloaded = (await calendar.getOccurrence(occ1.id))!;
      expect(occ1Reloaded.status, 'completed');
      expect(occ1Reloaded.executionSnapshotJson, isNull);
    });

    test('reset customization reverts snapshot to null and restores template resolution', () async {
      final allOccurrences = await calendar.getOccurrencesInLocalDateRange(
        startLocalDate: '2026-08-18',
        endLocalDate: '2026-09-10',
      );

      final upperOccurrences = allOccurrences
          .where((o) => o.sessionTemplateId == templateAId)
          .toList()
        ..sort((a, b) => a.effectiveLocalDate.compareTo(b.effectiveLocalDate));

      final occ1 = upperOccurrences[0];
      final occ2 = upperOccurrences[1];

      // Customize both via cascade
      final base1 = await calendar.readWorkoutPreviewSnapshot(occ1.id);
      await calendar.customizeFutureOccurrences(
        CustomizeFutureOccurrencesCommand(
          occurrenceId: occ1.id,
          commandId: 'cascade::all',
          expectedStatus: OccurrenceStatus.planned,
          baseSnapshotJson: base1,
          changes: [
            OccurrenceExerciseCustomization(
              prescriptionId: benchPrescriptionId,
              plannedSets: 4,
            ),
          ],
        ),
      );

      expect((await calendar.getOccurrence(occ1.id))!.executionSnapshotJson, isNotNull);
      expect((await calendar.getOccurrence(occ2.id))!.executionSnapshotJson, isNotNull);

      // Reset single occurrence (occ1)
      final resetSingleResult = await calendar.resetOccurrenceCustomization(
        ResetOccurrenceCustomizationCommand(
          occurrenceId: occ1.id,
          commandId: 'reset::occ1',
          expectedStatus: OccurrenceStatus.planned,
          allFuture: false,
        ),
      );

      expect(resetSingleResult.affectedCount, 1);
      expect((await calendar.getOccurrence(occ1.id))!.executionSnapshotJson, isNull);
      expect((await calendar.getOccurrence(occ2.id))!.executionSnapshotJson, isNotNull);

      // Reset all future from occ2
      final resetAllResult = await calendar.resetOccurrenceCustomization(
        ResetOccurrenceCustomizationCommand(
          occurrenceId: occ2.id,
          commandId: 'reset::all::occ2',
          expectedStatus: OccurrenceStatus.planned,
          allFuture: true,
        ),
      );

      expect(resetAllResult.affectedCount, 2); // occ2 and occ3
      for (final occ in upperOccurrences) {
        expect((await calendar.getOccurrence(occ.id))!.executionSnapshotJson, isNull);
      }
    });

    test('equipment compatibility accurately resolves canonical items and fails closed on unknown', () async {
      // Create a profile with Dumbbells and Bench only (no barbell, no cable)
      final profileId = await equipmentRepo.createProfile(
        name: 'Dumbbells & Bench',
        items: const [
          EquipmentProfileItemInput(equipmentCode: 'dumbbell'),
          EquipmentProfileItemInput(equipmentCode: 'bench'),
        ],
      );

      // Barbell exercise -> strictly incompatible
      final benchCompat = await equipmentRepo.checkCompatibility(
        profileId: profileId,
        exerciseEquipmentRequirement: 'Barbell',
      );
      expect(benchCompat.status, EquipmentCompatibilityStatus.incompatible);
      expect(benchCompat.unavailableEquipmentCodes, ['barbell']);

      // Dumbbell exercise -> compatible
      final dbCompat = await equipmentRepo.checkCompatibility(
        profileId: profileId,
        exerciseEquipmentRequirement: 'Dumbbell',
      );
      expect(dbCompat.status, EquipmentCompatibilityStatus.compatible);
      expect(dbCompat.unavailableEquipmentCodes, isEmpty);

      // Bodyweight exercise -> compatible
      final bwCompat = await equipmentRepo.checkCompatibility(
        profileId: profileId,
        exerciseEquipmentRequirement: 'Bodyweight',
      );
      expect(bwCompat.status, EquipmentCompatibilityStatus.compatible);

      // Exotic unrecognized equipment -> unknown (fails closed)
      final exoticCompat = await equipmentRepo.checkCompatibility(
        profileId: profileId,
        exerciseEquipmentRequirement: 'AntiGravityDevice',
      );
      expect(exoticCompat.status, EquipmentCompatibilityStatus.unknown);
    });

    test('stale base snapshot fails closed and leaves all targets unmodified', () async {
      final allOccurrences = await calendar.getOccurrencesInLocalDateRange(
        startLocalDate: '2026-08-18',
        endLocalDate: '2026-09-10',
      );

      final upperOccurrences = allOccurrences
          .where((o) => o.sessionTemplateId == templateAId)
          .toList();

      final firstUpper = upperOccurrences.first;

      // Passing bogus baseSnapshotJson triggers stale check
      expect(
        () => calendar.customizeFutureOccurrences(
          CustomizeFutureOccurrencesCommand(
            occurrenceId: firstUpper.id,
            commandId: 'stale::cmd',
            expectedStatus: OccurrenceStatus.planned,
            baseSnapshotJson: '{"stale": true}',
            changes: [
              OccurrenceExerciseCustomization(
                prescriptionId: benchPrescriptionId,
                plannedSets: 4,
              ),
            ],
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );

      // Verify none of the occurrences were touched
      for (final occ in upperOccurrences) {
        final reloaded = (await calendar.getOccurrence(occ.id))!;
        expect(reloaded.executionSnapshotJson, isNull);
      }
    });

    test('count-at-save accurately recomputes remaining unstarted targets', () async {
      final allOccurrences = await calendar.getOccurrencesInLocalDateRange(
        startLocalDate: '2026-08-18',
        endLocalDate: '2026-09-10',
      );

      final upperOccurrences = allOccurrences
          .where((o) => o.sessionTemplateId == templateAId)
          .toList()
        ..sort((a, b) => a.effectiveLocalDate.compareTo(b.effectiveLocalDate));

      final firstUpper = upperOccurrences[0];
      final middleUpper = upperOccurrences[1];

      // Mark middle occurrence as skipped before save
      await (db.update(db.scheduledSessionOccurrences)..where((t) => t.id.equals(middleUpper.id)))
          .write(
            const ScheduledSessionOccurrencesCompanion(
              status: Value('skipped'),
            ),
          );

      final baseSnapshot = await calendar.readWorkoutPreviewSnapshot(firstUpper.id);

      final result = await calendar.customizeFutureOccurrences(
        CustomizeFutureOccurrencesCommand(
          occurrenceId: firstUpper.id,
          commandId: 'recomputed::count',
          expectedStatus: OccurrenceStatus.planned,
          baseSnapshotJson: baseSnapshot,
          changes: [
            OccurrenceExerciseCustomization(
              prescriptionId: benchPrescriptionId,
              plannedSets: 4,
            ),
          ],
        ),
      );

      // Only first and last remain planned/rescheduled, count is 2 (middle skipped is excluded)
      expect(result.affectedCount, 2);
      expect((await calendar.getOccurrence(firstUpper.id))!.executionSnapshotJson, isNotNull);
      expect((await calendar.getOccurrence(middleUpper.id))!.executionSnapshotJson, isNull);
      expect((await calendar.getOccurrence(upperOccurrences[2].id))!.executionSnapshotJson, isNotNull);
    });
  });
}

Exercise _exercise(String stableId, String name, String equipment) {
  return Exercise(
    id: stableId.hashCode.abs(),
    stableId: stableId,
    name: name,
    muscleGroups: 'Chest',
    equipment: equipment,
    difficulty: 'Intermediate',
    formCues: '',
    commonMistakes: '',
    isCustom: false,
  );
}
