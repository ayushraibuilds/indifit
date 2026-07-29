import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/program_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = ProgramRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-05 ProgramRepository Authoring & Versioning Tests', () {
    test(
      '1. Creates a multi-block training program draft with deload week',
      () async {
        final programId = await repo.createProgram(
          name: 'Hypertrophy 8-Week',
          goal: 'Muscle Growth',
          notes: '2 blocks of 4 weeks',
          blocks: [
            ProgramBlockInput(
              name: 'Block 1 - Accumulation',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  name: 'Week 1',
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  isDeload: false,
                  templates: [
                    SessionTemplateInput(
                      name: 'Push Primary',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseNameSnapshot: 'Flat Barbell Bench Press',
                          plannedSets: 4,
                          repsRange: '8-10',
                          ordinal: 0,
                        ),
                      ],
                    ),
                  ],
                ),
                ProgramWeekInput(
                  name: 'Week 4 - Deload',
                  ordinalInBlock: 3,
                  programWeekOrdinal: 3,
                  isDeload: true,
                  templates: [
                    SessionTemplateInput(
                      name: 'Push Deload',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseNameSnapshot: 'Flat Barbell Bench Press',
                          plannedSets: 2,
                          repsRange: '10',
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

        final programs = await repo.getAllPrograms();
        expect(programs.length, equals(1));
        expect(programs.first.id, equals(programId));
        expect(programs.first.name, equals('Hypertrophy 8-Week'));

        final versions = await repo.getVersionsForProgram(programId);
        expect(versions.length, equals(1));
        expect(versions.first.versionNumber, equals(1));
        expect(versions.first.status, equals('draft'));

        final detail = await repo.getProgramVersionDetail(versions.first.id);
        expect(detail, isNotNull);
        expect(detail!.blocks.length, equals(1));
        expect(detail.weeks.length, equals(2));
        expect(detail.weeks.any((w) => w.isDeload), isTrue);
        expect(detail.exercisePrescriptions.length, equals(2));
      },
    );

    test(
      '2. Copying a published version creates a new editable draft v2',
      () async {
        final programId = await repo.createProgram(
          name: 'Strength Cycle',
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
                      name: 'Squat Heavy',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: [
                        const ExercisePrescriptionInput(
                          exerciseNameSnapshot: 'Barbell Back Squat',
                          plannedSets: 5,
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

        final v1 = (await repo.getVersionsForProgram(programId)).first;
        await repo.publishVersion(v1.id);

        final publishedV1 = (await repo.getVersionsForProgram(programId)).first;
        expect(publishedV1.status, equals('published'));
        expect(publishedV1.publishedAtUtc, isNotNull);

        // Copy published v1 -> draft v2
        final v2Id = await repo.copyToNewDraftVersion(v1.id);
        final v2Detail = await repo.getProgramVersionDetail(v2Id);

        expect(v2Detail, isNotNull);
        expect(v2Detail!.version.versionNumber, equals(2));
        expect(v2Detail.version.status, equals('draft'));
        expect(v2Detail.version.sourceVersionId, equals(v1.id));
        expect(
          v2Detail.exercisePrescriptions.first.exerciseNameSnapshot,
          equals('Barbell Back Squat'),
        );

        // Draft v2 can be updated
        await repo.updateDraftVersion(
          v2Id,
          blocks: [
            ProgramBlockInput(name: 'Block 1 Updated', ordinal: 0, weeks: []),
          ],
        );

        final updatedV2 = await repo.getProgramVersionDetail(v2Id);
        expect(updatedV2!.blocks.first.name, equals('Block 1 Updated'));
      },
    );

    test(
      '3. Modifying a published or archived version throws StateError',
      () async {
        final programId = await repo.createProgram(name: 'Immutable Test');
        final v1 = (await repo.getVersionsForProgram(programId)).first;

        await repo.publishVersion(v1.id);

        expect(
          () => repo.updateDraftVersion(v1.id, blocks: []),
          throwsA(isA<StateError>()),
        );

        await repo.archiveVersion(v1.id);

        expect(
          () => repo.updateDraftVersion(v1.id, blocks: []),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      '4. Delete draft version deletes draft, but rejects published deletion',
      () async {
        final programId = await repo.createProgram(name: 'Delete Test');
        final v1Id = (await repo.getVersionsForProgram(programId)).first.id;

        final v2Id = await repo.createDraftVersion(programId);
        expect((await repo.getVersionsForProgram(programId)).length, equals(2));

        await repo.deleteDraftVersion(v2Id);
        expect((await repo.getVersionsForProgram(programId)).length, equals(1));

        await repo.publishVersion(v1Id);
        expect(() => repo.deleteDraftVersion(v1Id), throwsA(isA<StateError>()));
      },
    );
  });
}
