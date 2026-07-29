import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/program_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository repository;

  setUp(() async {
    db = AppDatabase.memory();
    repository = ProgramRepository(db);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('exercise-bench-v1'),
            name: 'Flat Barbell Bench Press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
  });

  tearDown(() => db.close());

  ExercisePrescriptionInput prescription({int ordinal = 0}) {
    return ExercisePrescriptionInput(
      exerciseId: 'exercise-bench-v1',
      exerciseNameSnapshot: 'Flat Barbell Bench Press',
      plannedSets: 4,
      repsRange: '8-10',
      ordinal: ordinal,
    );
  }

  List<ProgramBlockInput> validGraph() {
    return [
      ProgramBlockInput(
        name: 'Accumulation',
        ordinal: 0,
        weeks: [
          ProgramWeekInput(
            name: 'Week 1',
            ordinalInBlock: 0,
            programWeekOrdinal: 0,
            templates: [
              SessionTemplateInput(
                name: 'Push',
                ordinal: 0,
                plannedWeekday: 1,
                prescriptions: [prescription()],
              ),
            ],
          ),
          ProgramWeekInput(
            name: 'Deload',
            ordinalInBlock: 1,
            programWeekOrdinal: 1,
            isDeload: true,
            templates: [
              SessionTemplateInput(
                name: 'Deload push',
                ordinal: 0,
                plannedWeekday: 1,
                prescriptions: [prescription()],
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Future<void> markPublished(String versionId) async {
    await (db.update(
      db.programVersions,
    )..where((row) => row.id.equals(versionId))).write(
      ProgramVersionsCompanion(
        status: const Value('published'),
        publishedAtUtc: Value(DateTime.utc(2026, 1, 1)),
      ),
    );
  }

  group('B01-05 program authoring and lifecycle', () {
    test('creates a validated multi-block draft with a deload week', () async {
      final programId = await repository.createProgram(
        name: 'Hypertrophy',
        blocks: validGraph(),
      );

      final version = (await repository.getVersionsForProgram(
        programId,
      )).single;
      final detail = await repository.getProgramVersionDetail(version.id);
      expect(version.status, 'draft');
      expect(detail!.weeks.map((week) => week.programWeekOrdinal), [0, 1]);
      expect(detail.weeks.last.isDeload, isTrue);
      expect(detail.exercisePrescriptions, hasLength(2));
      expect(
        detail.exercisePrescriptions.every(
          (prescription) => prescription.exerciseId == 'exercise-bench-v1',
        ),
        isTrue,
      );
    });

    test('rejects invalid graph before writing partial program rows', () async {
      await expectLater(
        repository.createProgram(
          name: 'Invalid',
          blocks: [ProgramBlockInput(name: 'Bad', ordinal: 1, weeks: const [])],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repository.getAllPrograms(), isEmpty);

      await expectLater(
        repository.createProgram(
          name: 'Unresolved without intent',
          blocks: [
            ProgramBlockInput(
              name: 'Block',
              ordinal: 0,
              weeks: [
                ProgramWeekInput(
                  ordinalInBlock: 0,
                  programWeekOrdinal: 0,
                  templates: [
                    SessionTemplateInput(
                      name: 'Template',
                      ordinal: 0,
                      plannedWeekday: 1,
                      prescriptions: const [
                        ExercisePrescriptionInput(
                          exerciseNameSnapshot: 'Unknown custom',
                          plannedSets: 1,
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
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repository.getAllPrograms(), isEmpty);
    });

    test(
      'copies a published version to an independently editable draft',
      () async {
        final programId = await repository.createProgram(
          name: 'Strength',
          blocks: validGraph(),
        );
        final v1 = (await repository.getVersionsForProgram(programId)).single;
        await markPublished(v1.id);

        final v2Id = await repository.copyToNewDraftVersion(v1.id);
        await repository.updateDraftVersion(v2Id, blocks: []);
        final v1Detail = await repository.getProgramVersionDetail(v1.id);
        final v2Detail = await repository.getProgramVersionDetail(v2Id);

        expect(v2Detail!.version.status, 'draft');
        expect(v2Detail.version.versionNumber, 2);
        expect(v2Detail.version.sourceVersionId, v1.id);
        expect(v1Detail!.exercisePrescriptions, hasLength(2));
        expect(v2Detail.exercisePrescriptions, isEmpty);
      },
    );

    test(
      'rejects published graph edits without deleting its children',
      () async {
        final programId = await repository.createProgram(
          name: 'Immutable',
          blocks: validGraph(),
        );
        final version = (await repository.getVersionsForProgram(
          programId,
        )).single;
        await markPublished(version.id);

        await expectLater(
          repository.updateDraftVersion(version.id, blocks: []),
          throwsA(isA<StateError>()),
        );
        expect(
          (await repository.getProgramVersionDetail(
            version.id,
          ))!.exercisePrescriptions,
          hasLength(2),
        );
      },
    );

    test('guards active and referenced draft deletion', () async {
      final programId = await repository.createProgram(
        name: 'Draft',
        blocks: [],
      );
      final version = (await repository.getVersionsForProgram(
        programId,
      )).single;
      await (db.update(
        db.trainingPlanSettings,
      )..where((row) => row.id.equals(1))).write(
        TrainingPlanSettingsCompanion(
          activeProgramVersionId: Value(version.id),
        ),
      );

      await expectLater(
        repository.deleteDraftVersion(version.id),
        throwsA(isA<StateError>()),
      );
      expect(await repository.getProgramVersionDetail(version.id), isNotNull);
    });

    test('repository and reactive provider share the database owner', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(programRepositoryProvider),
        isA<ProgramRepository>(),
      );
      expect(await container.read(programListProvider.future), isEmpty);
      await repository.createProgram(name: 'Provider graph');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(programListProvider).value, hasLength(1));
    });
  });
}
